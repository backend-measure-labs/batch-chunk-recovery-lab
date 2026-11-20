package lab.jobrunr;

import java.util.Map;

import org.jobrunr.jobs.Job;
import org.jobrunr.jobs.RecurringJob;
import org.jobrunr.storage.StorageProvider;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** 측정용: recurring 잡을 지금 한 번 넣는다(대시보드의 trigger 와 같은 동작). */
@RestController
public class TriggerController {

    private final StorageProvider storage;

    public TriggerController(StorageProvider storage) { this.storage = storage; }

    @PostMapping("/lab/trigger")
    public Map<String, String> trigger() {
        RecurringJob rj = storage.getRecurringJobs().stream()
                .filter(r -> CollectJob.ID.equals(r.getId())).findFirst()
                .orElseThrow(() -> new IllegalStateException("recurring job not registered"));
        Job job = storage.save(rj.toEnqueuedJob());
        return Map.of("jobId", job.getId().toString());
    }
}
