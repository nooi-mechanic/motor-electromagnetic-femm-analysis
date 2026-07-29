function codex_matlab_job_daemon()
% Simple file-driven job daemon for an already-open MATLAB Desktop session.
% Run this once manually inside the VM MATLAB Desktop. Codex can then drop
% request files over SSH/SCP without launching MATLAB itself.

base_dir = pwd;
request_path = fullfile(base_dir, 'codex_job_request.txt');
status_path = fullfile(base_dir, 'codex_job_status.txt');
heartbeat_path = fullfile(base_dir, 'codex_job_heartbeat.txt');
stop_path = fullfile(base_dir, 'codex_job_stop.txt');
lock_path = fullfile(base_dir, 'codex_job_running.lock');

write_status(status_path, 'DAEMON_START', 'MATLAB job daemon started');
disp('CODEX MATLAB job daemon started.');
disp(['Watching: ', request_path]);

while true
    write_text(heartbeat_path, sprintf('[%s] alive\n', datestr(now, 31)));

    if exist(stop_path, 'file')
        delete_if_exists(stop_path);
        write_status(status_path, 'DAEMON_STOP', 'Stop file detected');
        disp('CODEX MATLAB job daemon stopping.');
        return;
    end

    if exist(request_path, 'file') && ~exist(lock_path, 'file')
        write_text(lock_path, sprintf('[%s] running\n', datestr(now, 31)));
        try
            raw_cmd = strtrim(fileread(request_path));
            delete_if_exists(request_path);

            if isempty(raw_cmd)
                write_status(status_path, 'SKIP', 'Empty request');
            else
                write_status(status_path, 'JOB_START', raw_cmd);
                disp(['CODEX job start: ', raw_cmd]);
                evalin('base', raw_cmd);
                write_status(status_path, 'JOB_DONE', raw_cmd);
                disp(['CODEX job done: ', raw_cmd]);
            end
        catch ME
            write_status(status_path, 'JOB_FAIL', getReport(ME, 'extended', 'hyperlinks', 'off'));
            disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
        end
        delete_if_exists(lock_path);
    end

    pause(2);
    drawnow;
end
end

function write_status(path, tag, msg)
fid = fopen(path, 'a');
if fid < 0
    error('Could not open status file: %s', path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '[%s] %s %s\n', datestr(now, 31), tag, msg);
end

function write_text(path, txt)
fid = fopen(path, 'w');
if fid < 0
    error('Could not open file: %s', path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function delete_if_exists(path)
if exist(path, 'file')
    delete(path);
end
end
