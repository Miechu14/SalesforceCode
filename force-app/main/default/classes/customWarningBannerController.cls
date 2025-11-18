/*
    Custom Warning Banner Controller
    This Apex class retrieves custom labels based on the user's language settings.
*/
public with sharing class customWarningBannerController {

    @AuraEnabled(cacheable=true)
    public static String getLabel(String labelApiName) {
        if (String.isBlank(labelApiName)) {
            return null;
        }
        // Get the user's language
        String language = UserInfo.getLanguage();
        String namespace = null;
        // Check if the label exists for the user's language
        try {
        if (System.Label.translationExists(namespace, labelApiName, language)) {
            return System.Label.get(namespace, labelApiName, language);
        }
        else {return System.Label.get(namespace, labelApiName, 'en');
        }
        } catch (Exception e) {
            return '[Missing label: ' + labelApiName + ']';
        }
    }
}