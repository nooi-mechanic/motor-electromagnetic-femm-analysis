try
    fid = fopen(fullfile(pwd, 'matlab_nodesktop_probe_output.txt'), 'a');
    if fid < 0
        error('Could not open probe output file.');
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '[%s] nodesktop probe ok\n', datestr(now, 31));
    disp('NODEDESKTOP_PROBE_OK');
catch ME
    disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
    exit(1);
end

exit(0);
