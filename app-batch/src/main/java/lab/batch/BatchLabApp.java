package lab.batch;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = {"lab.core", "lab.batch"})
@EnableScheduling
public class BatchLabApp {
    public static void main(String[] args) {
        SpringApplication.run(BatchLabApp.class, args);
    }
}
