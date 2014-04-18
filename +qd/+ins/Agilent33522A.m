classdef Agilent33522A < qd.classes.ComInstrument
    properties
        ramp_rate_offset = 0.1;
    end
    
    methods
         function  obj = Agilent33522A(com)
            obj@qd.classes.ComInstrument(com);
         end
         
         function r = model(obj)
            r = 'Agilent33522A AWG';
         end
         
         function r = channels(obj)
            r = {'freq','volt','offset','wave'};
         end
        
         function turn_on_output(obj, output)
             switch output
                 case 1
                    obj.send('OUTP1 ON')
                 case 2
                     obj.send('OUTP2 ON')
             end
         end

         function turn_off_output(obj, output)
             switch output
                 case 1
                    obj.send('OUTP1 OFF')
                 case 2
                     obj.send('OUTP2 OFF')
             end
         end
         
          function val = getc(obj, output, channel)
                switch output
                  case 1
                    switch channel
                        case 'freq'
                            val = obj.querym('SOUR1:FREQ?', '%f');
                        case 'volt'
                            val = obj.querym('SOUR1:VOLT?', '%f');
                        case 'offset'
                            val = obj.querym('SOUR1:VOLT:OFFS?', '%f');
                        otherwise
                            error('not supported.')
                    end
                  case 2
                      switch channel
                        case 'freq'
                            val = obj.querym('SOUR2:FREQ?', '%f');
                        case 'volt'
                            val = obj.querym('SOUR2:VOLT?', '%f');
                        case 'offset'
                            val = obj.querym('SOUR2:VOLT:OFFS?', '%f');
                        otherwise
                            error('not supported.')
                      end
                end
          end
          
          function setc(obj, output, channel, value)
            switch output
                  case 1
                    switch channel
                        % Set et output mode. Choose between
                        % SIN,DC,SQU,RAMP,PULS,NOIS,PRBS,ARB
                        case 'wave'
                            obj.sendf('SOUR1:FUNC %s', value);
                        case 'freq'
                            obj.sendf('SOUR1:FREQ %.16E', value);
                        case 'volt'
                                obj.send('SOUR1:VOLT:UNIT VRMS'); % setting units to RMS voltage
                                obj.sendf('SOUR1:VOLT %.16E', value);
                        case 'offset'
                            % Use offset in DC mode
                            obj.sendf('SOUR1:VOLT:OFFS %.16E', value);
                        otherwise
                            error('not supported.')
                    end
                  case 2
                      switch channel
                            % Set et output mode. Choose between
                            % SIN,DC,SQU,RAMP,PULS,NOIS,PRBS,ARB
                            case 'wave'
                                obj.sendf('SOUR2:FUNC %s', value);
                            case 'freq'
                                obj.sendf('SOUR2:FREQ %.16E', value);
                            case 'volt'
                                obj.sendf('SOUR2:VOLT:UNIT VRMS'); % setting units to RMS voltage
                                obj.sendf('SOUR2:VOLT %.16E', value);
                            case 'offset'
                              % Use offset in DC mode
                              obj.sendf('SOUR2:VOLT:OFFS %.16E', value);
                            otherwise
                                error('not supported.')
                      end
            end   
          end
          
          function ramp_rate = get_ramp_rate_offset(obj)
              ramp_rate = obj.ramp_rate;
          end
          
          % Set to [], if ramping of offsets should be off.
          function set_ramp_rate_offset(obj, ramp_rate)
              obj.ramp_rate = ramp_rate;
          end
          
          function ramp_offset(obj, channel, value)
            current_value = getc(channel);
            steps = obj.calc_steps(current_value, value);
            channel_string = strsplit(channel,'CH');
            channel_num = channel_string{2};
            for i = 0:steps-1
                ramp_value = current_value + (value-current_value)/(steps-i);
                obj.send(sprintf('SOUR%s:VOLT:OFFS %.16E', channel_num, ramp_value));
                current_value = ramp_value;
                %Add a pause if needed
                %pause(0.05);
            end
          end
          
          function steps = calc_steps(obj, current_value, value)
              steps_raw = abs(current_value-value)/obj.get_ramp_rate_offset;
              steps = round(steps_raw);
          end
    end
end