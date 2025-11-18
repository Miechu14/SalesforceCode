@isTest
private class customWarningBannerControllerTest {
    @isTest
    static void getLabel_ReturnsNull() {
            string resultNull = customWarningBannerController.getLabel(null);
            string resultBlank = customWarningBannerController.getLabel('');
            System.assertEquals(
                null,
                resultNull,
                'Expecting null when ApiName is null'
            );    
             
            System.assertEquals(
                null,
                resultBlank,
                'Expecting null when ApiName is blank'
            );           
    }
    @isTest
    static void getLabel_ReturnsLabel() {
        string labelName = 'PaymentTermsRangeAlert'; 
        String expected = System.Label.PaymentTermsRangeAlert;
        string result = customWarningBannerController.getLabel(labelName);

        System.assertEquals(
            expected,
            result,
            'Expecting label value when ApiName is correct'
        );

    }

    @isTest
    static void getLabel_WithTranslations() {
        string labelName = 'PaymentTermsRangeAlert';     
        User u = [SELECT Id, LanguageLocaleKey FROM User WHERE Id = :UserInfo.getUserId()];
        u.LanguageLocaleKey = 'de';
        update u;
        String expected = System.Label.get(null, labelName, 'de');
        Test.startTest();
        string result = customWarningBannerController.getLabel(labelName);
        Test.stopTest();
        System.assertEquals(
            expected,
            result,
            'Expecting german label value when ApiName is correct and translation was found'
            );
 
    }
    @isTest
    static void getLabel_MissingTranslations() {
        string labelName = 'PaymentTermsRangeAlert'; 
        User u = [SELECT Id, LanguageLocaleKey FROM User WHERE Id = :UserInfo.getUserId()];
        u.LanguageLocaleKey = 'zh_CN';
        update u;
        String expected = System.Label.PaymentTermsRangeAlert;
        Test.startTest();
        string result = customWarningBannerController.getLabel(labelName);
        Test.stopTest();
        System.assertEquals(
            expected,
            result,
            'Expecting default label value when ApiName is correct and translation is missing'
            );    
    } 
    @isTest
    static void getLabel_WrongLabel() {
        string wrongLabel = 'NoLabelLikeThis';
        string result = customWarningBannerController.getLabel(wrongLabel);
        System.assertEquals(
            '[Missing label: ' + wrongLabel + ']',
            result,
            'Expecting error message when label was not found');
    }
}