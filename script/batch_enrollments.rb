f_name = File.expand_path(File.join(Rails.root, "tmp/enrollment_batch_handler.lock"))
f = begin
  File.new(f_name, File::CREAT|File::EXCL|File::WRONLY)
rescue
  nil
end
exit unless f
exit unless f.flock( File::LOCK_NB | File::LOCK_EX )
Listeners::EnrollmentEventBatchHandler.run
f.flock(File::LOCK_UN)
f.close
File.delete(f_name)
