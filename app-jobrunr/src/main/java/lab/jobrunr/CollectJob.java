package lab.jobrunr;

import org.jobrunr.jobs.annotations.Job;
import org.jobrunr.jobs.annotations.Recurring;
import org.springframework.stereotype.Component;

import lab.core.CollectService;

/** 5분 주기 recurring 잡. 재시도 2. */
@Component
public class CollectJob {

    public static final String ID = "gpu-usage-collect";

    private final CollectService service;

    public CollectJob(CollectService service) { this.service = service; }

    @Recurring(id = ID, cron = "*/5 * * * *")
    @Job(name = "gpu usage collect", retries = 2)
    public void run() {
        service.run();
    }
}
