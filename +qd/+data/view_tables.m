function tbls = view_tables(loc)
    num = 0;
    tbls = struct;
    for d = transpose(dir(fullfile(loc, '*.dat')))
        [~, table_name, ~] = fileparts(fullfile(loc, d.name));
        view = qd.data.view_table(qd.data.load_table(loc, table_name));
        if isvarname(table_name)
            tbls.(table_name) = view;
        end
        num = num + 1;
    end
end