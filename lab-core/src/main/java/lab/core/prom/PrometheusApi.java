package lab.core.prom;

import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.service.annotation.GetExchange;
import org.springframework.web.service.annotation.HttpExchange;

@HttpExchange
public interface PrometheusApi {

    @GetExchange("/api/v1/query_range")
    PromResponse queryRange(@RequestParam("query") String query,
                            @RequestParam("start") long start,
                            @RequestParam("end") long end,
                            @RequestParam("step") String step);
}
