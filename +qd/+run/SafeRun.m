classdef SafeRun < qd.run.StandardRun
    properties
        running = false;
        stopnow = false;
        plots = {} %Cell array containing plots
        data = [] %Data matrix for plotting
        zdata = [] %Data matrix for 2d surface plot
        %wdata = [] %Data matrix for waterfall plot
    end
    properties(Access=private)
        columns
    end
    methods
        function pause_run(obj)
            disp('Run will pause.');
            obj.running = false;
        end

        function continue_run(obj)
            disp('Run continued.');
            obj.running = true;
        end

        function stop_run(obj)
            disp('Run stopped.');
            obj.stopnow = true;
        end

        % varargin defines the plottype, points, line, color ..., e.g. 'r.-'
        function add_plot(obj, xname, yname, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('varargin') = varargin;
            p('fignum') = 0;
            p('title') = '';
            p('type') = '1d';
            obj.plots{end+1} = p;
        end

        % varargin defines be the colormap type: hot, jet ...
        function add_2dplot(obj, xname, yname, zname, title, fignum, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('zname') = zname;
            p('varargin') = varargin;
            p('fignum') = fignum;
            p('title') = title;
            p('type') = 'surface';
            obj.plots{end+1} = p;
        end

        % varargin defines the plot type: points or line ...
        function add_waterfall_plot(obj, xname, yname, title, fignum, varargin)
            p = containers.Map;
            p('xname') = xname;
            p('yname') = yname;
            p('varargin') = varargin;
            p('fignum') = fignum;
            p('title') = title;
            p('type') = 'waterfall';
            p('counter') = 0;
            obj.plots{end+1} = p;
        end

        function create_plots(obj)
            for pnum = 1:length(obj.plots)
                fignum = obj.plots{pnum}('fignum');
                if fignum>0
                    hFig = figure(fignum);
                else
                    hFig = figure();
                    obj.plots{pnum}('fignum') = hFig;
                end
                clf();
                varargin = obj.plots{pnum}('varargin');
                Keyset = {'zname'};
                surfaceplot = isKey(obj.plots{pnum},Keyset);
                mytitle = obj.plots{pnum}('title');
                if isempty(mytitle)
                    obj.plots{pnum}('title') = [obj.store.datestamp, '/', obj.store.timestamp, ' ', strrep(obj.store.name,'_','\_')];
                end
                if ~surfaceplot
                    h = plot(0,0,varargin{:});
                    obj.plots{pnum}('handle') = h;
                    xlabel(obj.plots{pnum}('xname'));
                    ylabel(obj.plots{pnum}('yname'));
                    title(obj.plots{pnum}('title'));
                else
                    type = obj.plots{pnum}('type');
                    if strcmp(type,'1d') || strcmp(type,'waterfall')
                        h = plot(NaN,NaN,varargin{:});
                        obj.plots{pnum}('handle') = h;
                        xname = obj.plots{pnum}('xname');
                        yname = obj.plots{pnum}('yname');
                        title1 = obj.plots{pnum}('title');
                        xlabel(xname);
                        ylabel(yname);
                        title(title1);
                    elseif strcmp(type,'surface')
                        x_limits = [obj.sweeps{1,1}.from obj.sweeps{1,1}.to];
                        y_limits = [obj.sweeps{1,2}.from obj.sweeps{1,2}.to];
                        x_extents = [min(x_limits) max(x_limits)];
                        y_extents = [min(y_limits) max(y_limits)];
                        xdata = obj.sweeps{1,1}.values;
                        ydata = obj.sweeps{1,2}.values;
                        obj.zdata = nan(length(ydata),length(xdata));
                        h = imagesc(x_extents, y_extents, obj.zdata);
                        colormap(varargin{:});
                        obj.plots{pnum}('handle') = h;
                        cb = colorbar;
                        set(gca,'YDir','normal');
                        xname = obj.plots{pnum}('xname');
                        yname = obj.plots{pnum}('yname');
                        zname = obj.plots{pnum}('zname');
                        xlabel(xname);
                        ylabel(yname);
                        ylabel(cb, zname);
                        title(mytitle);
                        title(title1);
                    else
                        error('Supported plottypes is: 1d, surface and waterfall');
                    end
                end
            end
        end

        function update_plots(obj, values)
            obj.data = [obj.data; values];
            for p = obj.plots
                p = p{1};
                h = p('handle');
                type = p('type');
                if strcmp(type,'1d')
                    xname = p('xname');
                    yname = p('yname');
                    xindex = not(cellfun('isempty', strfind(obj.columns, xname)));
                    yindex = not(cellfun('isempty', strfind(obj.columns, yname)));
                    x = obj.data(:,xindex);
                    y = obj.data(:,yindex);
                    % hold on doesn't do anything!
                    hold on;
                    try
                        set(h, 'XData', x', 'YData', y');
                    catch
                        obj.create_plots();
                        set(h, 'XData', x', 'YData', y');
                    end
                elseif strcmp(type,'surface')
                    inner_loop_points = obj.sweeps{1,2}.points;
                    outer_loop_points = obj.sweeps{1,1}.points;
                    zname = p('zname');
                    zindex = not(cellfun('isempty', strfind(obj.columns, zname)));
                    z = obj.data(:,zindex);
                    if ~mod(length(z),inner_loop_points)
                        if length(z) ~= inner_loop_points*outer_loop_points
                             dif = inner_loop_points.*outer_loop_points - length(z);
                             z = [z;nan(dif,1)];
                        end
                        obj.zdata = reshape(z,inner_loop_points,outer_loop_points);
                        set(h, 'Cdata', obj.zdata);
                    end
                elseif strcmp(type,'waterfall')
                    inner_loop_points = obj.sweeps{1,2}.points;
                    outer_loop_points = obj.sweeps{1,1}.points;
                    counter = p('counter');
                    xname = p('xname');
                    xindex = not(cellfun('isempty', strfind(obj.columns, xname)));
                    x = obj.data(:,xindex);
                    if ~mod(length(x),inner_loop_points)
                        yname = p('yname');
                        yindex = not(cellfun('isempty', strfind(obj.columns, yname)));
                        y = obj.data(inner_loop_points*counter+1:inner_loop_points+inner_loop_points*counter,yindex);
                        x = obj.data(inner_loop_points*counter+1:inner_loop_points+inner_loop_points*counter,xindex);
                        figure(p('fignum'));
                        h = plot(x,y);
                        set(h,'color',hsv2rgb([1-counter/(outer_loop_points-1) 1 1]));
                        p('handle') = h;
                        hold on;
                        p('counter') = counter+1;
                    end
                end
            end
        end

        function save_plots(obj)
            for plot = obj.plots
                figure(plot{1}('fignum'));
                name = [strrep(plot{1}('xname'),'/','_'), '_vs_', strrep(plot{1}('yname'),'/','_')];
                saveas(gcf, [obj.store.directory, '/', name, '.png'], 'png');
            end
        end

        function obj = sweep(obj, name_or_channel, from, to, points, varargin)
            p = inputParser();
            p.addOptional('settle', 0);
            p.addOptional('tolerance', []);
            p.addOptional('values', []);
            p.addOptional('alternate', false);
            p.parse(varargin{:});
            sweep = struct();
            sweep.from = from;
            sweep.to = to;
            sweep.points = points;
            sweep.settle = p.Results.settle;
            sweep.tolerance = p.Results.tolerance;
            sweep.alternate = p.Results.alternate;
            if(isempty(p.Results.values))
                sweep.values = linspace(from, to, points);
            else
                sweep.values = p.Results.values;
            end
            sweep.chan = obj.resolve_channel(name_or_channel);
            if(strcmp(name_or_channel,'time/time') && (sweep.from == 0))
                sweep.chan.instrument.reset;
            end
            obj.sweeps{end + 1} = sweep;
        end
    end
    

    methods(Access=protected)
        function perform_run(obj, out_dir)
            % This table will hold the data collected.
            table = qd.data.TableWriter(out_dir, 'data');
            obj.columns = {};
            for sweep = obj.sweeps
                table.add_channel_column(sweep{1}.chan);
                obj.columns{end+1} = sweep{1}.chan.name;
            end
            for inp = obj.inputs
                table.add_channel_column(inp{1});
                obj.columns{end+1} = inp{1}.name;
            end
            table.init();
            obj.running = true;
            obj.stopnow = false;
            % Start meas control window.
            hMeasControl = meas_control(obj);
            % Create plots
            obj.create_plots();
            % Now perform all the measurements.
            obj.handle_sweeps(obj.sweeps, [], table);
            close(hMeasControl);
        end

        function handle_sweeps(obj, sweeps, earlier_values, table)
        % obj.handle_sweeps(sweeps, earlier_values, settle, table)
        %
        % Sweeps the channels in sweeps, takes measurements and puts them in
        % table.
        %
        % sweeps is a cell array of structs with the fields: from, to, points,
        % chan, and settle. Rows will be added to table which look like:
        % [earlier_values sweeps inputs] where earlier_values is an array of
        % doubles, sweeps, is the current value of each swept parameter, and
        % inputs are the measured inputs (the channels in obj.inputs). Settle
        % is the amount of time to wait before measuring a sample (in ms).

            % If there are no more sweeps left, let the system settle, then
            % measure one point.
            if isempty(sweeps)
                %values = [earlier_values];
                values = [];
                futures = {};
                for sweep = obj.sweeps
                    futures{end + 1} = sweep{1}.chan.get_async();
                end
                for inp = obj.inputs
                    futures{end + 1} = inp{1}.get_async();
                end
                for future = futures
                    values(end + 1) = future{1}.exec();
                end
                % Add data point
                table.add_point(values); % Write data point to file
                obj.update_plots(values);
                drawnow();
                if obj.running
                    return
                else
                    disp('Click continue.');
                    while (not(obj.running) && not(obj.stopnow))
                        pause(1);
                    end
                    return
                end
            end

            % Sweep one channel. Within the loop, recusively call this
            % function with one less channel to sweep.
            sweep = sweeps{1};
            next_sweeps = sweeps(2:end);
            if(obj.is_time_chan(sweep.chan) && (~sweep.points))
                % This is supposed to run until sweep.to time has passed,
                % and then measure as many points as possible during the given time.
                % sometimes you don't know how long it takes to set a channel
                settle = 0;
                settle = max(settle, sweep.settle);
                % Go to starting point and begin timer
                sweep.chan.set(sweep.from);
                while true
                    value = sweep.chan.get();
                    if value > sweep.to
                        break
                    end
                    if obj.stopnow
                        break
                    end
                    obj.handle_sweeps(next_sweeps, [earlier_values value], table);
                end
            else
                for value = sweep.values
                    sweep.chan.set(value);
                    if ~isempty(sweep.tolerance)
                        curval = sweep.chan.get();
                        fprintf('Setting %s=%f to %f\r',sweep.chan.name,curval,value);
                        while true
                            curval = sweep.chan.get();
                            if abs(value-curval)<sweep.tolerance
                                break;
                            else
                                pause(sweep.settle);
                            end
                        end
                    else
                        pause(sweep.settle);
                    end
                    %settle = max(settle, sweep.settle);
                    obj.handle_sweeps(next_sweeps, [earlier_values value], table);
                    if ~isempty(next_sweeps)
                        % Nicely seperate everything for gnuplot.
                        table.add_divider();
                    end
                    % If the measurement has to be stopped, break here
                    if obj.stopnow
                        break
                    end
                end
            end
        end
    end
end
