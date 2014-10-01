classdef multiple_DecaDAC < qd.classes.ComInstrument
% this class manages multiple DecaDAC2 objects and
% allows to add, remove them and allows to call one
% certain channel without caring which DecaDAC it
% actually is
    properties
        DecaDACs = {};
    end
    properties(Dependent)
        DACs
        limits
        offset
        divider
    end
    
    methods
        % Function to get dependent variables:
        function DACs = get.DACs(obj)
            DACs = struct();
            for DecaDAC = obj.DecaDACs
                name = DecaDAC{1}.name;
                if isvarname(name)
                    DACs.(name) = DecaDAC{1};
                end
            end
            
        end
        function limits = get.limits(obj)
            limits = struct();                                              % Create structure for limits
            i = 0;                                                          % Create a counter
            for DecaDAC = obj.DecaDACs                                      % Loop over DACs in the system
                 names = fieldnames(DecaDAC{1}.limits);                     % Get all channels from dac
                 for n = names'                                             % Loop over the channels
                     limits.(['CH' num2str(i)]) = DecaDAC{1}.limits.(n{:}); % Save the limits
                     i = i+1;                                               % Step the counter
                 end
            end
        end
        function offset = get.offset(obj)
            offset = struct();
            i = 0;
            for DecaDAC = obj.DecaDACs
                names = fieldnames(DecaDAC{1}.offset);
                for n = names'
                    offset.(['CH' num2str(i)]) = DecaDAC{1}.offset.(n{:});
                    i = i+1;
                end
            end
        end
        function divider = get.divider(obj)
            divider = struct();
            i = 0;
            for DecaDAC = obj.DecaDACs
                names = fieldnames(DecaDAC{1}.divider);
                for n = names'
                    divider.(['CH' num2str(i)]) = DecaDAC{1}.divider.(n{:});
                    i = i+1;
                end
            end
        end
        
        % Functions to set dependent variables
        function set_limits(obj, ch, limits)
            ch = str2double(ch(3:end));
            if ( (ch >= numel(obj.DecaDACs)*20) || (ch < 0) )
                error('Not supported.')
            else
                DACno = floor(ch/20)+1;
                CHno = mod(ch,20);
                obj.DecaDACs{DACno}.limits.(['CH' num2str(CHno)]) = limits;
            end
        end
        function set_divider(obj, channel, divider)
            channel = str2double(channel(3:end));                           % Channel number, eg. 17
            if ( (channel >= numel(obj.DecaDACs)*20) || (channel < 0) )     % Checking that channel exists
                error('Not supported.')
            else
                DACno = floor(channel/20)+1;                                % Find the appropriate DAC
                DACchannel = ['CH' num2str(mod(channel,20))];               % Calculate the channel number of DAC
                obj.DecaDACs{DACno}.setDivider(DACchannel,divider)          % Set division factor
            end
        end
        function set_offset(obj, channel, offset)
            channel = str2double(channel(3:end));                           % Channel number, eg. 17
            if ( (channel >= numel(obj.DecaDACs)*20) || (channel < 0) )     % Checking that channel exists
                error('Not supported.')
            else
                DACno = floor(channel/20)+1;                                % Find the appropriate DAC
                DACchannel = ['CH' num2str(mod(channel,20))];               % Calculate the channel number of DAC
                obj.DecaDACs{DACno}.setOffset(DACchannel,offset)            % Set division factor
            end
        end
        
        % Function to add a DecaDAC to system
        function add_DecaDAC(obj,DecaDAC)
            obj.DecaDACs{end+1} = DecaDAC;
        end

        function val = getc(obj, ch)
            channel = ch;                                                   % String containing channel ID. eg CH17
            ch = str2double(ch(3:end));                                     % Channel number, eg. 17
            if ( (ch >= numel(obj.DecaDACs)*20) || (ch < 0) )               % Checking that channel exists
                error('Not supported.')
            else
                DACno = floor(ch/20)+1;                                     % Find the appropriate DAC
                CHno = mod(ch,20);                                          % Calculate the channel number of DAC
                val = obj.DecaDACs{DACno}.getc(['CH' num2str(CHno)]);       % Get the value from DAC
                val = (val + obj.offset.(channel))/obj.divider.(channel);   % Correct for offset and division factor
            end
        end
        
        function calibrateChannel(obj,ch,data)
            ch = str2double(ch(3:end));                                     % Channel number, eg. 17
            if ( (ch >= numel(obj.DecaDACs)*20) || (ch < 0) )               % Checking that channel exists
                error('Not supported.')
            else
                DACno = floor(ch/20)+1;                                     % Find the appropriate DAC
                CHno = mod(ch,20);                                          % Calculate the channel number of DAC
                obj.DecaDACs{DACno}.calibrateChannel(['CH' num2str(CHno)],data);            % Calibrate DAC channel
            end
        end
        
        function r = channels(obj)
            noDACs = numel(obj.DecaDACs);
            r = qd.util.map(@(n)['CH' num2str(n)], 0:(20*noDACs-1));
        end
        
        function future = setc_async(obj, ch, value)
            ch = str2double(ch(3:end));                                     % Channel number, eg. 17
            if ( (ch >= numel(obj.DecaDACs)*20) || (ch < 0) )               % Checking that channel exists
                error('Not supported.')
            else
                DACno = floor(ch/20)+1;                                     % Find the appropriate DAC
                CHno = mod(ch,20);                                          % Calculate the channel number of DAC
                obj.DecaDACs{DACno}.setc(['CH' num2str(CHno)], value);      % Send value to DAC
                future = qd.classes.SetFuture.do_nothing_future;
            end
        end
        
    end
    

    methods (Static)
        function r = model()
            r = 'multiple_DecaDACs';
        end
    end
end