package lab.batch;

import java.time.Clock;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.explore.JobExplorer;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 5분 @Scheduled. 같은 잡이 돌고 있으면 띄우지 않는다.
 * 잡 파라미터 end = 지금(주입 Clock, 랩에서는 T0 고정).
 */
@RestController
public class Launcher {

    private static final Logger log = LoggerFactory.getLogger(Launcher.class);

    private final JobLauncher launcher;
    private final JobExplorer explorer;
    private final Job job;
    private final Clock clock;
    private final TaskScheduler scheduler;

    public Launcher(JobLauncher launcher, JobExplorer explorer, Job job, Clock clock, TaskScheduler scheduler) {
        this.launcher = launcher;
        this.explorer = explorer;
        this.job = job;
        this.clock = clock;
        this.scheduler = scheduler;
    }

    @Scheduled(cron = "0 */5 * * * *")
    public void scheduled() { launch("schedule"); }

    @PostMapping("/lab/trigger")
    public Map<String, String> trigger() {
        scheduler.schedule(() -> launch("trigger"), java.time.Instant.now());
        return Map.of("accepted", "true");
    }

    void launch(String by) {
        Set<JobExecution> running = explorer.findRunningJobExecutions(BatchJobConfig.JOB);
        if (!running.isEmpty()) {
            for (JobExecution e : running) {
                log.warn("SKIP_RUNNING by={} executionId={} status={} start={}", by, e.getId(), e.getStatus(),
                        e.getStartTime());
            }
            return;
        }
        try {
            JobExecution e = launcher.run(job, new JobParametersBuilder()
                    .addLong("end", clock.instant().getEpochSecond()).toJobParameters());
            log.info("LAUNCH_DONE by={} executionId={} status={}", by, e.getId(), e.getStatus());
        } catch (Exception ex) {
            log.warn("LAUNCH_REJECTED by={} error={}", by, ex.toString());
        }
    }
}
