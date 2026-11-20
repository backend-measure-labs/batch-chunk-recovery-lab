package lab.core;

import java.net.http.HttpClient;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Properties;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.support.RestClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;

import com.zaxxer.hikari.HikariDataSource;

import jakarta.persistence.EntityManagerFactory;
import lab.core.prom.BodyByteCounter;
import lab.core.prom.PrometheusApi;

/**
 * 데이터소스 둘: 주(잡 러너 저장소) · 원천(수집 테이블). 원천만 JPA.
 */
@Configuration
@EnableTransactionManagement
@EnableConfigurationProperties(LabProperties.class)
public class LabCoreConfig {

    @Bean
    public Clock clock(LabProperties p) {
        return Clock.fixed(Instant.ofEpochSecond(p.getT0()), ZoneOffset.UTC);
    }

    @Bean
    public PrometheusApi prometheusApi(LabProperties p) {
        JdkClientHttpRequestFactory rf = new JdkClientHttpRequestFactory(
                HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
        rf.setReadTimeout(Duration.ofMinutes(10));
        RestClient client = RestClient.builder()
                .baseUrl(p.getPrometheusUrl())
                .requestFactory(rf)
                .requestInterceptor(new BodyByteCounter())
                .build();
        return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(client)).build()
                .createClient(PrometheusApi.class);
    }

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource")
    public DataSourceProperties primaryDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    public HikariDataSource dataSource(@Qualifier("primaryDataSourceProperties") DataSourceProperties p) {
        HikariDataSource ds = p.initializeDataSourceBuilder().type(HikariDataSource.class).build();
        ds.setPoolName("primary");
        return ds;
    }

    @Bean
    @ConfigurationProperties("lab.source.datasource")
    public DataSourceProperties sourceDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    public HikariDataSource sourceDataSource(@Qualifier("sourceDataSourceProperties") DataSourceProperties p) {
        HikariDataSource ds = p.initializeDataSourceBuilder().type(HikariDataSource.class).build();
        ds.setPoolName("source");
        return ds;
    }

    @Bean
    public LocalContainerEntityManagerFactoryBean sourceEntityManagerFactory(
            @Qualifier("sourceDataSource") DataSource ds) {
        LocalContainerEntityManagerFactoryBean f = new LocalContainerEntityManagerFactoryBean();
        f.setDataSource(ds);
        f.setPersistenceUnitName("source");
        f.setPackagesToScan("lab.core.store");
        f.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
        Properties jpa = new Properties();
        jpa.put("hibernate.hbm2ddl.auto", "none");
        jpa.put("hibernate.jdbc.batch_size", "500");
        jpa.put("hibernate.order_inserts", "true");
        jpa.put("hibernate.jdbc.time_zone", "UTC");
        f.setJpaProperties(jpa);
        return f;
    }

    @Bean
    public PlatformTransactionManager sourceTransactionManager(
            @Qualifier("sourceEntityManagerFactory") EntityManagerFactory emf) {
        return new JpaTransactionManager(emf);
    }
}
