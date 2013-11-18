public with sharing class SignupRequestUtil {
	
	public static void createNewSignupRequests() {
		List<SignupRequest> srlist = new List<SignupRequest>();
		Integer j=0;
		for(Integer i=0; i<200; i++) {
		    SignupRequest sr = new SignupRequest(); 
		    Integer rand = Crypto.getRandomInteger();
		    if(rand<0) rand *= -1;
		    String newSFUsername = rand+'@cloudconversion.com';
		    sr.SignupEmail = newSFUsername;
		    sr.Username = newSFUsername;
		    sr.FirstName = 'Admin';
		    sr.LastName = 'Admin';
		    sr.Country = 'US';
		    sr.Company = 'Cloud Conversion';
		    sr.TemplateId = '0TT8000000002dT';
		    srList.add(sr);
		}
		Database.insert(srlist, false);
	}
	
	public static void 	processNewSignupRequests(Datetime dt) {
		List<Salesforce_Org__c> sfList = new List<Salesforce_Org__c>();
		Set<String> sfUsernames = new Set<String>();
		for(SignupRequest sr : [Select Id, CreatedOrgId, Username From
		    SignupRequest Where Status='Success' AND CreatedDate>:dt]) {
		    sfUsernames.add(sr.Username);
		}
		
		Map<String,sfLma__License__c> sfOrgMap = new Map<String,sfLma__License__c>();
		for(sfLma__License__c l : [Select Id, sfLma__Subscriber_Org_ID__c, Username__c From sfLma__License__c Where Username__c IN :sfUsernames]) {
		    if(!sfOrgMap.containsKey(l.Username__c)) sfOrgMap.put(l.Username__c, l);
		}
		
		for(SignupRequest sr : [Select Id, CreatedOrgId, Username From SignupRequest Where Status='Success' AND CreatedDate>:dt]) {
		    Salesforce_Org__c sfo = new Salesforce_Org__c();
		    sfLma__License__c l = sfOrgMap.get(sr.Username);
		    if(l!=null) {
		       sfo.SF_Org_Id__c = l.sfLma__Subscriber_Org_ID__c;
		       sfo.License__c = l.Id;
		       sfo.Signup_Request__c = sr.Id;
		       sfo.Username__c = sr.Username;
		       sfList.add(sfo);
		    }
		}
		Database.insert(sfList, false);
	}
}