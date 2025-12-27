/**
 * @description Test class for TrailForge_ContentBuilderController
 * Tests course, module, and lesson creation with quiz assignment
 */
@IsTest
private class TrailForge_ContentBuilderController_Test {
    
    /**
     * @description Creates shared test data for quiz assignment tests
     */
    @TestSetup
    static void setupTestData() {
        // Create a quiz for assignment tests
        Quiz__c testQuiz = new Quiz__c(
            Name = 'Test Quiz for Assignment',
            Active__c = true,
            Passing_Score__c = 70
        );
        insert testQuiz;
    }
    
    /**
     * @description Test creating a course with only required fields
     */
    @IsTest
    static void createCourseOnly_withRequiredFields_createsCourseSuccessfully() {
        // Arrange
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Test Course Only';
        courseDTO.description = 'A simple test course';
        courseDTO.active = true;
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act
        Test.startTest();
        TrailForge_ContentBuilderController.ContentCreationResultDTO result = 
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.success, 'Course creation should succeed');
        System.assertNotEquals(null, result.courseId, 'Course ID should be populated');
        System.assertEquals(0, result.moduleIds.size(), 'No modules should be created');
        System.assertEquals(0, result.lessonIds.size(), 'No lessons should be created');
        
        // Verify course record
        Course__c createdCourse = [SELECT Id, Name, Description__c, Active__c FROM Course__c WHERE Id = :result.courseId];
        System.assertEquals('Test Course Only', createdCourse.Name, 'Course name should match');
        System.assertEquals('A simple test course', createdCourse.Description__c, 'Description should match');
        System.assertEquals(true, createdCourse.Active__c, 'Course should be active');
    }
    
    /**
     * @description Test creating a course with multiple modules
     */
    @IsTest
    static void createCourseWithModules_multipleModules_createsAllModulesWithCorrectOrder() {
        // Arrange
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Course with Modules';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        // Create 3 modules
        for (Integer i = 1; i <= 3; i++) {
            TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
            moduleDTO.name = 'Module ' + i;
            moduleDTO.orderNumber = i;
            moduleDTO.summary = 'Summary for module ' + i;
            courseDTO.modules.add(moduleDTO);
        }
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act
        Test.startTest();
        TrailForge_ContentBuilderController.ContentCreationResultDTO result = 
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.success, 'Creation should succeed');
        System.assertNotEquals(null, result.courseId, 'Course ID should be populated');
        System.assertEquals(3, result.moduleIds.size(), 'Should create 3 modules');
        System.assertEquals(0, result.lessonIds.size(), 'No lessons should be created');
        
        // Verify modules and their order
        List<Module__c> modules = [
            SELECT Id, Name, Order__c, Summary__c, Course__c 
            FROM Module__c 
            WHERE Course__c = :result.courseId 
            ORDER BY Order__c ASC
        ];
        
        System.assertEquals(3, modules.size(), 'Should have 3 modules in database');
        
        for (Integer i = 0; i < modules.size(); i++) {
            System.assertEquals('Module ' + (i + 1), modules[i].Name, 'Module name should match');
            System.assertEquals(i + 1, modules[i].Order__c, 'Order should be correct');
            System.assertEquals('Summary for module ' + (i + 1), modules[i].Summary__c, 'Summary should match');
            System.assertEquals(result.courseId, modules[i].Course__c, 'Module should be linked to course');
        }
    }
    
    /**
     * @description Test creating a course with modules and lessons
     */
    @IsTest
    static void createCourseWithModulesAndLessons_fullStructure_createsCorrectHierarchy() {
        // Arrange
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Full Course Structure';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        // Create 2 modules, each with 2 lessons
        for (Integer m = 1; m <= 2; m++) {
            TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
            moduleDTO.name = 'Module ' + m;
            moduleDTO.orderNumber = m;
            moduleDTO.lessons = new List<TrailForge_ContentBuilderController.LessonDTO>();
            
            for (Integer l = 1; l <= 2; l++) {
                TrailForge_ContentBuilderController.LessonDTO lessonDTO = new TrailForge_ContentBuilderController.LessonDTO();
                lessonDTO.name = 'Module ' + m + ' - Lesson ' + l;
                lessonDTO.orderNumber = l;
                lessonDTO.contentType = 'Markdown';
                moduleDTO.lessons.add(lessonDTO);
            }
            
            courseDTO.modules.add(moduleDTO);
        }
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act
        Test.startTest();
        TrailForge_ContentBuilderController.ContentCreationResultDTO result = 
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.success, 'Creation should succeed');
        System.assertEquals(2, result.moduleIds.size(), 'Should create 2 modules');
        System.assertEquals(4, result.lessonIds.size(), 'Should create 4 lessons total');
        
        // Verify lesson hierarchy
        List<Lesson__c> lessons = [
            SELECT Id, Name, Order__c, Content_Type__c, Module__c, Module__r.Name, Module__r.Course__c
            FROM Lesson__c 
            WHERE Module__r.Course__c = :result.courseId 
            ORDER BY Module__r.Order__c, Order__c ASC
        ];
        
        System.assertEquals(4, lessons.size(), 'Should have 4 lessons in database');
        
        // Verify first module's lessons
        System.assertEquals('Module 1 - Lesson 1', lessons[0].Name, 'First lesson name should match');
        System.assertEquals(1, lessons[0].Order__c, 'First lesson order should be 1');
        System.assertEquals('Markdown', lessons[0].Content_Type__c, 'Content type should be Markdown');
        
        // Verify all lessons are linked to correct modules
        for (Lesson__c lesson : lessons) {
            System.assertEquals(result.courseId, lesson.Module__r.Course__c, 'Lesson should be under correct course');
        }
    }
    
    /**
     * @description Test assigning an existing quiz to a lesson
     */
    @IsTest
    static void createCourseWithLessonAndQuiz_existingQuiz_assignsQuizCorrectly() {
        // Arrange - Get the quiz created in TestSetup
        Quiz__c existingQuiz = [SELECT Id, Name FROM Quiz__c WHERE Name = 'Test Quiz for Assignment' LIMIT 1];
        
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Course with Quiz Lesson';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
        moduleDTO.name = 'Quiz Module';
        moduleDTO.orderNumber = 1;
        moduleDTO.lessons = new List<TrailForge_ContentBuilderController.LessonDTO>();
        
        TrailForge_ContentBuilderController.LessonDTO lessonDTO = new TrailForge_ContentBuilderController.LessonDTO();
        lessonDTO.name = 'Quiz Lesson';
        lessonDTO.orderNumber = 1;
        lessonDTO.contentType = 'Quiz';
        lessonDTO.quizId = existingQuiz.Id;
        moduleDTO.lessons.add(lessonDTO);
        
        courseDTO.modules.add(moduleDTO);
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act
        Test.startTest();
        TrailForge_ContentBuilderController.ContentCreationResultDTO result = 
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.success, 'Creation should succeed');
        System.assertEquals(1, result.lessonIds.size(), 'Should create 1 lesson');
        
        // Verify quiz is assigned to lesson
        Lesson__c createdLesson = [SELECT Id, Name, Quiz__c FROM Lesson__c WHERE Id = :result.lessonIds[0]];
        System.assertEquals(existingQuiz.Id, createdLesson.Quiz__c, 'Quiz should be assigned to lesson');
    }
    
    /**
     * @description Test that missing course name throws an error
     */
    @IsTest
    static void createCourse_missingName_throwsError() {
        // Arrange
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = ''; // Empty name
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act & Assert
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // AuraHandledException may wrap the message, just verify exception was thrown
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'An exception should have been thrown for missing course name');
        Test.stopTest();
    }
    
    /**
     * @description Test that missing module name throws an error
     */
    @IsTest
    static void createCourseWithModule_missingModuleName_throwsError() {
        // Arrange
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Valid Course';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
        moduleDTO.name = ''; // Empty name
        moduleDTO.orderNumber = 1;
        courseDTO.modules.add(moduleDTO);
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act & Assert
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // AuraHandledException may wrap the message, just verify exception was thrown
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'An exception should have been thrown for missing module name');
        Test.stopTest();
    }
    
    /**
     * @description Test that missing lesson name throws an error
     */
    @IsTest
    static void createCourseWithLesson_missingLessonName_throwsError() {
        // Arrange
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Valid Course';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
        moduleDTO.name = 'Valid Module';
        moduleDTO.orderNumber = 1;
        moduleDTO.lessons = new List<TrailForge_ContentBuilderController.LessonDTO>();
        
        TrailForge_ContentBuilderController.LessonDTO lessonDTO = new TrailForge_ContentBuilderController.LessonDTO();
        lessonDTO.name = ''; // Empty name
        lessonDTO.orderNumber = 1;
        moduleDTO.lessons.add(lessonDTO);
        
        courseDTO.modules.add(moduleDTO);
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act & Assert
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // AuraHandledException may wrap the message, just verify exception was thrown
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'An exception should have been thrown for missing lesson name');
        Test.stopTest();
    }
    
    /**
     * @description Test getAvailableQuizzes returns active quizzes
     */
    @IsTest
    static void getAvailableQuizzes_withActiveQuizzes_returnsQuizList() {
        // Arrange - Quiz created in TestSetup
        
        // Act
        Test.startTest();
        List<TrailForge_ContentBuilderController.QuizOptionDTO> quizzes = 
            TrailForge_ContentBuilderController.getAvailableQuizzes();
        Test.stopTest();
        
        // Assert
        System.assert(quizzes.size() >= 1, 'Should return at least 1 quiz');
        
        Boolean foundTestQuiz = false;
        for (TrailForge_ContentBuilderController.QuizOptionDTO quiz : quizzes) {
            if (quiz.name == 'Test Quiz for Assignment') {
                foundTestQuiz = true;
                System.assertNotEquals(null, quiz.quizId, 'Quiz ID should be populated');
                break;
            }
        }
        System.assert(foundTestQuiz, 'Should find the test quiz');
    }
    
    /**
     * @description Test assignQuizToLesson updates lesson correctly
     */
    @IsTest
    static void assignQuizToLesson_validLessonAndQuiz_assignsSuccessfully() {
        // Arrange
        Quiz__c existingQuiz = [SELECT Id FROM Quiz__c WHERE Name = 'Test Quiz for Assignment' LIMIT 1];
        
        // Create a course structure first
        Course__c course = new Course__c(Name = 'Test Course');
        insert course;
        
        Module__c mod = new Module__c(Name = 'Test Module', Course__c = course.Id, Order__c = 1);
        insert mod;
        
        Lesson__c lesson = new Lesson__c(Name = 'Test Lesson', Module__c = mod.Id, Order__c = 1);
        insert lesson;
        
        // Act
        Test.startTest();
        Boolean result = TrailForge_ContentBuilderController.assignQuizToLesson(lesson.Id, existingQuiz.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result, 'Assignment should succeed');
        
        Lesson__c updatedLesson = [SELECT Id, Quiz__c FROM Lesson__c WHERE Id = :lesson.Id];
        System.assertEquals(existingQuiz.Id, updatedLesson.Quiz__c, 'Quiz should be assigned');
    }
    
    /**
     * @description Test creating a large course structure
     */
    @IsTest
    static void createCourse_largeStructure_handlesMultipleRecordsCorrectly() {
        // Arrange - Create course with 5 modules, each with 3 lessons
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Large Course';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        for (Integer m = 1; m <= 5; m++) {
            TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
            moduleDTO.name = 'Module ' + m;
            moduleDTO.orderNumber = m;
            moduleDTO.lessons = new List<TrailForge_ContentBuilderController.LessonDTO>();
            
            for (Integer l = 1; l <= 3; l++) {
                TrailForge_ContentBuilderController.LessonDTO lessonDTO = new TrailForge_ContentBuilderController.LessonDTO();
                lessonDTO.name = 'M' + m + ' Lesson ' + l;
                lessonDTO.orderNumber = l;
                lessonDTO.contentType = 'Markdown';
                moduleDTO.lessons.add(lessonDTO);
            }
            
            courseDTO.modules.add(moduleDTO);
        }
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Act
        Test.startTest();
        TrailForge_ContentBuilderController.ContentCreationResultDTO result = 
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.success, 'Creation should succeed');
        System.assertEquals(5, result.moduleIds.size(), 'Should create 5 modules');
        System.assertEquals(15, result.lessonIds.size(), 'Should create 15 lessons');
        
        // Verify counts in database
        Integer moduleCount = [SELECT COUNT() FROM Module__c WHERE Course__c = :result.courseId];
        Integer lessonCount = [SELECT COUNT() FROM Lesson__c WHERE Module__r.Course__c = :result.courseId];
        
        System.assertEquals(5, moduleCount, 'Database should have 5 modules');
        System.assertEquals(15, lessonCount, 'Database should have 15 lessons');
    }
    
    /**
     * @description Test that transaction rolls back on error
     */
    @IsTest
    static void createCourse_errorDuringCreation_rollsBackAllChanges() {
        // Arrange - Create a course with valid module but invalid lesson
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        courseDTO.name = 'Rollback Test Course';
        courseDTO.modules = new List<TrailForge_ContentBuilderController.ModuleDTO>();
        
        TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
        moduleDTO.name = 'Valid Module';
        moduleDTO.orderNumber = 1;
        moduleDTO.lessons = new List<TrailForge_ContentBuilderController.LessonDTO>();
        
        // First lesson is valid
        TrailForge_ContentBuilderController.LessonDTO validLesson = new TrailForge_ContentBuilderController.LessonDTO();
        validLesson.name = 'Valid Lesson';
        validLesson.orderNumber = 1;
        moduleDTO.lessons.add(validLesson);
        
        // Second lesson has no name - should cause error
        TrailForge_ContentBuilderController.LessonDTO invalidLesson = new TrailForge_ContentBuilderController.LessonDTO();
        invalidLesson.name = '';
        invalidLesson.orderNumber = 2;
        moduleDTO.lessons.add(invalidLesson);
        
        courseDTO.modules.add(moduleDTO);
        
        String courseJson = JSON.serialize(courseDTO);
        
        // Count records before
        Integer coursesBefore = [SELECT COUNT() FROM Course__c WHERE Name = 'Rollback Test Course'];
        
        // Act
        Test.startTest();
        try {
            TrailForge_ContentBuilderController.createCourseContent(courseJson);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Expected
        }
        Test.stopTest();
        
        // Assert - no records should have been created
        Integer coursesAfter = [SELECT COUNT() FROM Course__c WHERE Name = 'Rollback Test Course'];
        System.assertEquals(coursesBefore, coursesAfter, 'No course should be created due to rollback');
    }
    
    /**
     * @description Test DTO default constructors
     */
    @IsTest
    static void dtoConstructors_newInstances_initializeCorrectly() {
        // Act
        TrailForge_ContentBuilderController.CourseDTO courseDTO = new TrailForge_ContentBuilderController.CourseDTO();
        TrailForge_ContentBuilderController.ModuleDTO moduleDTO = new TrailForge_ContentBuilderController.ModuleDTO();
        TrailForge_ContentBuilderController.LessonDTO lessonDTO = new TrailForge_ContentBuilderController.LessonDTO();
        TrailForge_ContentBuilderController.ContentCreationResultDTO resultDTO = new TrailForge_ContentBuilderController.ContentCreationResultDTO();
        TrailForge_ContentBuilderController.QuizOptionDTO quizDTO = new TrailForge_ContentBuilderController.QuizOptionDTO();
        
        // Assert
        System.assertNotEquals(null, courseDTO.modules, 'CourseDTO modules should be initialized');
        System.assertEquals(true, courseDTO.active, 'CourseDTO active should default to true');
        System.assertNotEquals(null, moduleDTO.lessons, 'ModuleDTO lessons should be initialized');
        System.assertNotEquals(null, resultDTO.moduleIds, 'ResultDTO moduleIds should be initialized');
        System.assertNotEquals(null, resultDTO.lessonIds, 'ResultDTO lessonIds should be initialized');
        System.assertEquals(false, resultDTO.success, 'ResultDTO success should default to false');
    }
}
