//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
public with sharing class EnrollmentRecalcInvoker {
    @InvocableMethod(
        label='Recalculate Enrollment Progress'
        description='Recalculate the parent enrollment progress after a lesson is completed or updated.'
    )
    public static void recalc(List<Id> enrollmentIds) {
        if (enrollmentIds == null || enrollmentIds.isEmpty()) {
            return;
        }
        
        // Convert to Set and delegate to bulk method for governor-safe processing
        Set<Id> ids = new Set<Id>(enrollmentIds);
        EnrollmentService.recalculateEnrollmentProgressBulk(ids);
    }
}