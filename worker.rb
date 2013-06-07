require 'set'

class Job
  include Comparable
  def initialize(time=Time.now, &job)
    @job = job
    @time = time
  end

  def time
    @time
  end

  def now?
    Time.now >= @time
  end

  def call
    @job.call()
  end

  def <=>(job)
    self.time<=>job.time
  end
end

class Worker
  def initialize
    @jobs = []
    @mutex = Mutex.new
    @thread = Thread.new { thread_loop }
  end

  def join
    @thread.join
  end

  def thread_loop
    loop {
      sleep(0.05)
      do_jobs
    }
  end

  def do_jobs
    #puts "Worker loop #{@jobs.length}"
    if @jobs.length > 0

      job_to_do = nil
      @mutex.synchronize {
        @jobs.sort!
        job_to_do = @jobs[0]

      if job_to_do.now?
        @jobs.delete(job_to_do)
      else
        job_to_do=nil
      end
      }

      job_to_do.call if !job_to_do.nil?
    end
  end

  def add_job(&block)
    @mutex.synchronize {
      @jobs << Job.new{ block }
    }
    @thread.run
  end

  def timer(time, &block)
    @mutex.synchronize {
      @jobs << Job.new(Time.now+time) {block.call}
    }
  end

end