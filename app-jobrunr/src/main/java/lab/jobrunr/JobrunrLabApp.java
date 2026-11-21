package lab.jobrunr;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = {"lab.core", "lab.jobrunr"})
public class JobrunrLabApp {
    public static void main(String[] args) {
        SpringApplication.run(JobrunrLabApp.class, args);
    }
}
