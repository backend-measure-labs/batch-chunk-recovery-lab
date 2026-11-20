package lab.core.prom;

import java.util.List;
import java.util.Map;

/** query_range 응답. 원문을 String 으로 받지 않고 Jackson 이 바로 이 모양으로 역직렬화한다. */
public record PromResponse(String status, Data data, String errorType, String error) {

    public record Data(String resultType, List<GenericResult> result) { }

    /** 점 하나 = [epoch, "값"] 리스트 */
    public record GenericResult(Map<String, String> metric, List<Object> values) { }
}
