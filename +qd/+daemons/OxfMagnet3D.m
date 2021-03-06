classdef OxfMagnet3D < handle
    properties(Constant)
        bind_address = 'tcp://127.0.0.1:9738/'
    end

    properties
        check_period = 3*60
        limit1_pt2 = 4.0
        limit2_pt2 = 4.5
        limit1_cool_water = 20
        limit2_cool_water = 21
        ramp_to_zero_rate = 0.03; % Tesla/min.
        % All the available axes of the magnet. When using Triton 6, set this
        % to 'xz' since it only has a 2d magnet.
        axes = 'xyz'
    end
    properties(SetAccess=private)
        magnet_serial
        magnet
        triton
        pt2_chan
        cool_water_chan
        server
        status = 'ok'
    end

    methods

        % Call as OxfMagnet3D('COM1') or OxfMagnet3D('COM1', 'no_triton'). If
        % the 'no_triton' parameter is added, the magnet will not contact the
        % cryostat to check for temperature rises.
        function obj = OxfMagnet3D(com_port, varargin)
            p = inputParser();
            p.addOptional('no_triton', [], @(x)strcmp(x, 'no_triton'));
            p.parse(varargin{:});
            obj.magnet_serial = serial(com_port);
            % If you want to use Ethernet connection to mercury UPS: ping times are faster,
            % I guess it would be speed up if there is a direct conntection pypassing the LAN - Merlin
            % obj.magnet_serial = visa('ni','TCPIP::172.20.??.??::7020::SOCKET');
            fopen(obj.magnet_serial);
            obj.magnet = qd.protocols.OxfordSCPI(...
                @(req)query(obj.magnet_serial, req, '%s\n', '%s\n'));
            if p.Results.no_triton
                obj.triton = [];
            else
                obj.triton = qd.ins.Triton();
            end
            obj.server = daemon.Daemon(obj.bind_address);
            obj.server.daemon_name = 'oxfmagnet3d-daemon';
            obj.server.expose(obj, 'set');
            obj.server.expose(obj, 'force_set');
            obj.server.expose(obj, 'force_set_base');
            obj.server.expose(obj, 'read');
            obj.server.expose(obj, 'read_base');
            obj.server.expose(obj, 'get_report');
            obj.server.expose(obj, 'reset_status');
            obj.server.expose(obj, 'get_axes');
        end

        function run_daemon(obj)
            if ~isempty(obj.triton)
                obj.pt2_chan = qd.comb.MemoizeChannel( ...
                    obj.triton.channel('PT2'), obj.check_period/2);
                obj.cool_water_chan = qd.comb.MemoizeChannel( ...
                    obj.triton.channel('cooling_water'), obj.check_period/2);
            end
            while true % loop forever
                try
                    obj.server.serve_period(obj.check_period);
                    obj.perform_check()
                catch err
                    obj.server.send_alert_from_exception(...
                        'Error in magnet control server', err);
                end
            end
        end

        function val = read(obj, axis, prop, varargin)
            val = obj.magnet.read([obj.axis_addr(axis) prop], varargin{:});
        end

        function r = set(obj, axis, prop, value, varargin)
            obj.assert_conditions_ok();
            obj.force_set(axis, prop, value, varargin{:});
            r = [];
        end

        function val = read_base(obj, prop, varargin)
            val = obj.magnet.read(prop, varargin{:});
        end

        function r = force_set_base(obj, prop, value, varargin)
            obj.magnet.set(prop, value, varargin{:});
            r = [];
        end

        function ok = conditions_ok(obj)
            obj.perform_check();
            ok = strcmp(obj.status, 'ok');
        end

        function perform_check(obj)
            if obj.at_zero_field()
                return
            end
            if strcmp(obj.status, 'level2')
                return
            end
            if ~isempty(obj.triton)
                if obj.pt2_chan.get() > obj.limit2_pt2 ...
                    || obj.cool_water_chan.get() > obj.limit2_cool_water
                    obj.trip_level2();
                end
            end
            if strcmp(obj.status, 'level1')
                return
            end
            if ~isempty(obj.triton)
                if obj.pt2_chan.get() > obj.limit1_pt2 ...
                    || obj.cool_water_chan.get() > obj.limit1_cool_water
                    obj.trip_level1();
                end
            end
        end

        function r = at_zero_field(obj)
            r = true;
            for axis = obj.axes
                if obj.read(axis, 'SIG:FSET', '%fT') ~= 0
                    r = false;
                    return;
                elseif abs(obj.read(axis, 'SIG:FLD', '%fT')) > 1E-3
                    r = false;
                    return;
                end
            end
        end

        function trip_level2(obj)
            if strcmp(obj.status, 'level2')
                return
            end
            for axis = obj.axes
                % Hold all when overheating as requested by oxford.
                obj.force_set(axis, 'ACTN', 'HOLD');
            end
            obj.status = 'level2';
            obj.server.send_alert('Magnet at level2 overheating', obj.get_report());
        end

        function trip_level1(obj)
            % First level of protection tries to ramp the field to zero.
            % This goes against oxfords request to just hold the magnet.
            % If the temperature keeps increasing. Then we hold as requested.

            if strcmp(obj.status, 'level1') || strcmp(obj.status, 'level2')
                return
            end
            
            obj.server.send_alert('Magnet at level1 overheating', obj.get_report());
            obj.status = 'level1';

            % If the magnet is in persistent mode, don't do anything. (the user will
            % have to respond).
            for i = 1:length(obj.axes)
                persist = obj.read(obj.axes(i), 'SIG:SWHT');
                if strcmp(persist, 'OFF')
                    obj.server.send_alert('Cannot ramp magnet to zero', ...
                        'Magnet is in persistent mode, cannot ramp to zero automatically.')
                end
            end
            
            % Bring to zero along direction of field. Vect will hold the
            % direction.
            vect = zeros(0, length(obj.axes));
            for i = 1:length(obj.axes)
                % We assume here that the magnet is not in persistent mode.
                vect(i) = obj.read(obj.axes(i), 'SIG:FLD', '%fT');
            end
            % We set the ramp rate with positive numbers.
            vect = abs(vect);
            % Add a small value to each component to avoid degenerate cases.
            vect = vect + 0.01;
            vect = vect/norm(vect) * obj.ramp_to_zero_rate;
            for i = 1:length(obj.axes)
                % We assume here that the magnet is not in persistent mode.
                obj.force_set(obj.axes(i), 'ACTN', 'HOLD');
                obj.force_set(obj.axes(i), 'SIG:RFST', vect(i), '%.16f');
                obj.force_set(obj.axes(i), 'ACTN', 'RTOZ');
            end
        end

        function reset_status(obj)
            obj.status = 'ok';
        end

        function assert_conditions_ok(obj)
            if ~obj.conditions_ok()
                error('It is not safe to operate the magnet now:\n%s', obj.get_report());
            end
        end

        function report = get_report(obj)
            if ~isempty(obj.triton)
                report = sprintf('PT2: %f\nCooling water: %f\nStatus: %s\n', ...
                    obj.pt2_chan.get(), obj.cool_water_chan.get(), obj.status);
            else
                report = 'Triton communication disabled by no_triton flag.';
            end
        end

        function force_set(obj, axis, prop, value, varargin)
            obj.magnet.set([obj.axis_addr(axis) prop], value, varargin{:});
        end

        function addr = axis_addr(obj, axis)
            qd.util.assert(length(axis));
            qd.util.assert(ismember(axis, 'xyzXYZ'));
            addr = ['DEV:GRP' upper(axis) ':PSU:'];
        end

        function delete(obj)
            if ~isempty(obj.magnet_serial)
                fclose(obj.magnet_serial);
            end
        end

        function axes = get_axes(obj)
            axes = obj.axes;
        end
    end
end
