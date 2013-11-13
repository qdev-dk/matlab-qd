classdef HRDecaDAC < qd.classes.ComInstrument
    % - Use the HRDecaDAC driver as you use the DecaDac drivers.
    % - The HR version supports corarse and fine channels, set by
    %   *.set_board_mode({1,2,2,2,2}); % Modes 0:off, 1:fine  2:coarse
    %   Do so before you access channels, i.e. before naming them. I did not
    %   implement many fool-safe parts.
    % - you can add offsets and slopes to the channels.
    % - blind ramping (set_setpoint) sets fine channel first, which might be
    %   a voltage jump of 100mV, use it with care!
    %
    % ToDo: Make a lookup file to save slopes and offsets and read them back
    properties(Access=private)
        board_mode = {2,2,2,2,2} % Modes 0:off, 1:fine  2:coarse.
    end
    
    methods
        function obj = HRDecaDAC(port)
            obj.com = serial(port, ...
                'BaudRate', 57600, ...
                'Parity',   'none', ...
                'DataBits', 8, ...
                'StopBits', 1);
            fopen(obj.com); % will be closed on delete by ComInstrument.
            obj.set_board_mode(obj.board_mode) % to Coarse by default
        end
        
        function r = model(obj)
            r = 'DecaDAC';
        end

        function r = channels(obj)
            r = qd.util.map(@(n)['CH' num2str(n)], 0:19);
        end

        function chan = channel(obj, id)
            try
                n = qd.util.match(id, 'CH%d');
            catch
                error('No such channel (%s).', id);
            end
            mode = obj.board_mode{floor(n/4)+1};
            chan = qd.ins.HRDecaDACChannel(n,mode);
            chan.channel_id = id;
            chan.instrument = obj;
        end

        function set_board_mode(obj, boards)
            obj.board_mode = boards;
            % Put the boards in OFF, Coarse or Fine modes
            % Modes: 0:off, 1:fine  2:coarse.
            for i = 1:5;
                mode = boards{i};
                if ~any(mode == [0,1,2])
                    mode = 0;
                    warning('Mode must be 0,1, or 2. Now set to 0')
                end
                obj.queryf('B%d;M%d;', i-1, mode);
            end
        end
        
        
        function r = get_board_mode(obj)
            r = obj.board_mode;
        end
        
        function r = describe(obj, register)
            r = obj.describe@qd.classes.ComInstrument(register);
            r.current_values = struct();
            for q = obj.channels()
                r.current_values.(q{1}) = obj.getc(q{1});
            end
        end
    end
end