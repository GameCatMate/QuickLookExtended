package demo.quicklook;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class SampleApp {
    public static void main(String[] args) {
        var service = new ReportService(List.of("api", "worker", "scheduler"));
        service.render(Map.of("environment", "staging", "version", "1.4.2"));
    }
}

final class ReportService {
    private final List<String> components;

    ReportService(List<String> components) {
        this.components = components;
    }

    void render(Map<String, String> labels) {
        System.out.println("QuickLook report at " + Instant.now());
        labels.forEach((key, value) -> System.out.printf("%s=%s%n", key, value));
        for (String component : components) {
            System.out.println("component " + component + " is healthy");
        }
    }
}
