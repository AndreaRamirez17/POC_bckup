package com.cicd.pipeline.poc;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * Basic test class to enable code coverage reporting with JaCoCo
 */
@SpringBootTest
@TestPropertySource(properties = {
    "server.port=0",  // Use random port for testing
    "spring.main.lazy-initialization=true"  // Speed up test execution
})
class CicdPipelinePocApplicationTest {

    @Test
    void contextLoads() {
        // This test verifies that the Spring application context loads successfully
        assertNotNull(CicdPipelinePocApplication.class);
    }

    @Test
    void mainMethodTest() {
        // Test the main method doesn't throw exceptions
        // This is a simple smoke test
        String[] args = {};
        CicdPipelinePocApplication.main(args);
        assertNotNull(CicdPipelinePocApplication.class);
    }
}