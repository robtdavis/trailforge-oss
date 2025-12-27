// Update Lesson 2.1 with multi-slide content
Lesson__c lesson = [SELECT Id, Content_Body__c FROM Lesson__c WHERE Id = 'a03E200000vXU8mIAG' LIMIT 1];

lesson.Content_Body__c = '# Welcome to Core Concepts\n\n' +
    'This lesson will cover the fundamental concepts you need to understand.\n\n' +
    '---\n\n' +
    '# What Are Core Concepts?\n\n' +
    'Core concepts are the building blocks of knowledge in any field. They include:\n\n' +
    '- **Foundational Principles**: The basic rules and theories\n' +
    '- **Key Terminology**: Important terms you need to know\n' +
    '- **Best Practices**: Proven methods for success\n\n' +
    '---\n\n' +
    '# Why Core Concepts Matter\n\n' +
    'Understanding core concepts is essential because:\n\n' +
    '1. They provide a framework for learning\n' +
    '2. They help you make connections between ideas\n' +
    '3. They enable you to solve complex problems\n\n' +
    '---\n\n' +
    '# Summary\n\n' +
    'In this lesson, we covered:\n' +
    '- What core concepts are\n' +
    '- Why they matter\n' +
    '- How to apply them\n\n' +
    'Click "Complete Lesson" when you are ready to move on.';

update lesson;

System.debug('Lesson updated with multi-slide content');
System.debug('Content length: ' + lesson.Content_Body__c.length());
