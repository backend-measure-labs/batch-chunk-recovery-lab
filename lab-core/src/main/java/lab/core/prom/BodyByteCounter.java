package lab.core.prom;

import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpRequest;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;

/** 응답 본문 바이트를 버퍼링 없이 센다(스트림을 감싸기만 한다). */
public class BodyByteCounter implements ClientHttpRequestInterceptor {

    private static final ThreadLocal<long[]> COUNT = ThreadLocal.withInitial(() -> new long[1]);

    public static void reset() { COUNT.get()[0] = 0; }

    public static long bytes() { return COUNT.get()[0]; }

    @Override
    public ClientHttpResponse intercept(HttpRequest request, byte[] body, ClientHttpRequestExecution execution)
            throws IOException {
        ClientHttpResponse response = execution.execute(request, body);
        return new ClientHttpResponse() {
            @Override public HttpStatusCode getStatusCode() throws IOException { return response.getStatusCode(); }
            @Override public String getStatusText() throws IOException { return response.getStatusText(); }
            @Override public HttpHeaders getHeaders() { return response.getHeaders(); }
            @Override public void close() { response.close(); }
            @Override public InputStream getBody() throws IOException {
                long[] c = COUNT.get();
                return new FilterInputStream(response.getBody()) {
                    @Override public int read() throws IOException {
                        int b = super.read();
                        if (b >= 0) c[0]++;
                        return b;
                    }
                    @Override public int read(byte[] buf, int off, int len) throws IOException {
                        int n = super.read(buf, off, len);
                        if (n > 0) c[0] += n;
                        return n;
                    }
                };
            }
        };
    }
}
