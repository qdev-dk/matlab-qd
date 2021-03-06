function reply = send_cmd(cmd)
    sock = zmq.socket('req');
    sock.bind('tcp://127.0.0.1:37544');
    sock.send(cmd);
    r = sock.recv('multi');
    qd.util.assert(strcmp(r{1}, 'ack'));
    reply = r(2:end);
end