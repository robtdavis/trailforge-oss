//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Structured logging utility for TrailForge
 * Provides consistent error/info logging across the application
 * Future: Can be extended to integrate with external logging systems
 */
public with sharing class Logger {
    
    /**
     * Log an error with structured context
     * Currently uses System.debug but provides extensibility point
     * 
     * @param serviceName Name of the service/class logging the error
     * @param methodName Name of the method where error occurred
     * @param errorMessage Error message or exception message
     * @param recordCount Number of records affected (if applicable)
     */
    public static void logError(
        String serviceName,
        String methodName,
        String errorMessage,
        Integer recordCount
    ) {
        String logMessage = String.format(
            '[{0}.{1}] Error: {2} | Records affected: {3}',
            new List<String>{
                serviceName,
                methodName,
                errorMessage,
                String.valueOf(recordCount)
            }
        );
        
        System.debug(LoggingLevel.ERROR, logMessage);
        
        // Future: Publish to Platform Event for persistent logging
        // Future: Create Error_Log__c record
        // Future: Send critical errors to external monitoring (e.g., Sentry, New Relic)
    }
    
    /**
     * Log an error with exception details
     * 
     * @param serviceName Name of the service/class logging the error
     * @param methodName Name of the method where error occurred
     * @param ex Exception that was caught
     * @param recordCount Number of records affected (if applicable)
     */
    public static void logError(
        String serviceName,
        String methodName,
        Exception ex,
        Integer recordCount
    ) {
        String logMessage = String.format(
            '[{0}.{1}] {2}: {3} | Stack: {4} | Records affected: {5}',
            new List<String>{
                serviceName,
                methodName,
                ex.getTypeName(),
                ex.getMessage(),
                ex.getStackTraceString(),
                String.valueOf(recordCount)
            }
        );
        
        System.debug(LoggingLevel.ERROR, logMessage);
        
        // Future: Capture full exception context
    }
    
    /**
     * Log informational message (e.g., performance metrics)
     * 
     * @param serviceName Name of the service/class
     * @param methodName Name of the method
     * @param message Informational message
     */
    public static void logInfo(
        String serviceName,
        String methodName,
        String message
    ) {
        String logMessage = String.format(
            '[{0}.{1}] {2}',
            new List<String>{
                serviceName,
                methodName,
                message
            }
        );
        
        System.debug(LoggingLevel.INFO, logMessage);
    }
    
    /**
     * Log performance warning (e.g., slow queries)
     * 
     * @param serviceName Name of the service/class
     * @param methodName Name of the method
     * @param elapsedMs Elapsed time in milliseconds
     * @param recordCount Number of records processed
     */
    public static void logPerformance(
        String serviceName,
        String methodName,
        Long elapsedMs,
        Integer recordCount
    ) {
        String logMessage = String.format(
            '[{0}.{1}] Performance: {2}ms for {3} records',
            new List<String>{
                serviceName,
                methodName,
                String.valueOf(elapsedMs),
                String.valueOf(recordCount)
            }
        );
        
        LoggingLevel level = elapsedMs > 5000 ? LoggingLevel.WARN : LoggingLevel.INFO;
        System.debug(level, logMessage);
    }
}