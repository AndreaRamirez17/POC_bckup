package com.banamex.gating.poc.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HealthController {
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("timestamp", LocalDateTime.now());
        response.put("service", "gating-poc-app");
        response.put("version", "1.0.0");
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> response = new HashMap<>();
        response.put("application", "CI/CD Gating PoC");
        response.put("description", "Mock application with intentional vulnerabilities for testing gates");
        response.put("vulnerabilities", Map.of(
            "critical", "log4j 2.14.1 (CVE-2021-44228)",
            "high", "commons-collections 3.2.1 (CVE-2015-6420)",
            "medium", "jackson-databind 2.9.10.1"
        ));
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/status")
    public ResponseEntity<String> status() {
        return ResponseEntity.ok("Service is running");
    }
}