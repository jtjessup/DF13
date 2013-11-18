global with sharing class ProcessSalesforceBillingEmail implements Messaging.InboundEmailHandler {
  global Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email, Messaging.InboundEnvelope envelope) { 
	// Create a new inboundEmailResult object - for returning the result of the Apex code
	Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
  	try {
	    Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.allowFieldTruncation = true;
	
	    system.debug(logginglevel.warn,'Start Processing Tracking Email');
	    system.debug(logginglevel.warn,'email.subject='+email.subject); 
	    //system.debug(logginglevel.warn,'email.htmlBody='+email.htmlBody);
	    //system.debug(logginglevel.warn,'email.plainTextBody='+email.plainTextBody); 

		/*String emailToAddress = '';
	    if(email.toAddresses!=null && email.toAddresses.size() > 0) {
	      for(integer i = 0 ; i < email.toAddresses.size() ; i++) {
			if(email.toAddresses[i]!=null) {
				if(email.toAddresses[i].indexOf('<') > 0 && email.toAddresses[i].indexOf('>') > 0) {
				  emailToAddress += email.ToAddresses[i].subString(email.ToAddresses[i].indexOf('<')+1,email.ToAddresses[i].indexOf('>'));
				} else {
				  emailToAddress += email.toAddresses[i];
				}
		        if(i>0) emailToAddress += '; ';
		        system.debug(logginglevel.warn,'Insert Email TO: ' + email.toAddresses[i]);
			}
	      }
	    }*/

	    String body = email.plainTextBody;
	    
	    String textBody = '';
	    System.debug('num text attachments='+email.textAttachments.size());
        if(email.textAttachments!=null && email.textAttachments.size() > 0) {
			for(integer i = 0 ; i < email.textAttachments.size() ; i++) {
		        String mimeTypeSubType = email.textAttachments[i].mimeTypeSubType;
		        system.debug(logginglevel.warn,'mimeTypeSubType='+mimeTypeSubType);
				if(mimeTypeSubType!=null) body += 'mimeType='+mimeTypeSubType+'\n';
			    //if(email.textAttachments[i].body!=null) textBody += email.textAttachments[i].body+'\n';
			    //System.debug('textAttachment['+i+']='+email.textAttachments[i].body);
			}
        }
        //System.debug('textBody='+textBody);

        Map<String,Util.InvoiceInfo> invoiceInfo = new Map<String,Util.InvoiceInfo>();
		List<String> accountNames = new List<String>();
		List<String> invoiceNumbers = new List<String>();
        if(email.binaryAttachments!=null && email.binaryAttachments.size() > 0) {
        	system.debug(logginglevel.warn,'email.binaryAttachments.size()='+email.binaryAttachments.size());
	        if(email.binaryAttachments.size()>1) { // it's a bulk import
				for(integer i = 0 ; i < email.binaryAttachments.size() ; ++i) {
					if(Math.mod(i,2)!=0) {
				        String mimeTypeSubType = email.binaryAttachments[i].mimeTypeSubType;
				        system.debug(logginglevel.warn,'mimeTypeSubType='+mimeTypeSubType);
						if(mimeTypeSubType!=null) body += 'mimeType='+mimeTypeSubType+'\n';
						//binaryBlob = email.binaryAttachments[i].body;
					    if(email.binaryAttachments[i].body!=null && email.binaryAttachments[i].body.toString()!=null) {
					       //binaryBody += email.binaryAttachments[i].body.toString()+'\n';
					       //System.debug('binaryAttachment['+i+']='+email.binaryAttachments[i].body.toString());
					       Util.InvoiceInfo ii = Util.getInvoiceInfo(email.binaryAttachments[i].body.toString(), email.binaryAttachments[i-1].body); 
					       if(ii!=null) {
					       	  if(ii.poNumber!=null) invoiceInfo.put(ii.poNumber, ii);
	        				  else invoiceInfo.put(ii.accountName, ii);
	        				  accountNames.add(ii.accountName);
	        				  invoiceNumbers.add(ii.invoiceNumber);
					       }
					    }
					}
				}
	        } else {
	        	Util.InvoiceInfo ii = Util.getInvoiceInfo(body, email.binaryAttachments[0].body);
	        	if(ii!=null) {
	        		if(ii.poNumber!=null) invoiceInfo.put(ii.poNumber, ii);
	        		else invoiceInfo.put(ii.accountName, ii);
	        		accountNames.add(ii.accountName);
	        		invoiceNumbers.add(ii.invoiceNumber);
	        	}
	        }
        }

		if(invoiceInfo!=null && invoiceInfo.size()>0) {
			System.debug('invoiceInfo='+invoiceInfo);
			System.debug('accountNames='+accountNames);
		    Map<String,CHANNEL_ORDERS__Service_Order__c> orderMap = new Map<String,CHANNEL_ORDERS__Service_Order__c>();
		    for(CHANNEL_ORDERS__Service_Order__c o : [Select Id, Name, Account__c, Account__r.Name From CHANNEL_ORDERS__Service_Order__c 
		                                              Where Name IN: invoiceInfo.keySet()]) {
			    orderMap.put(o.Name,o);
			}
			
		    Map<String,CHANNEL_ORDERS__Service_Order__c> orderAccountMap = new Map<String,CHANNEL_ORDERS__Service_Order__c>();
		    for(CHANNEL_ORDERS__Service_Order__c o : [Select Id, Name, CHANNEL_ORDERS__Customer_Name__c, Account__c, Account__r.Name From CHANNEL_ORDERS__Service_Order__c 
		                                              Where CHANNEL_ORDERS__Customer_Name__c IN :accountNames]) {
			    orderAccountMap.put(o.CHANNEL_ORDERS__Customer_Name__c,o);
			}
			
			List<Account> accountsToUpdate  = new List<Account>();
			List<CHANNEL_ORDERS__Service_Order__c> ordersToUpdate  = new List<CHANNEL_ORDERS__Service_Order__c>();
			List<cloudsv__Salesforce_Invoice__c> invoicesToUpsert = new List<cloudsv__Salesforce_Invoice__c>();
			for(Util.InvoiceInfo ii : invoiceInfo.values()) {
				CHANNEL_ORDERS__Service_Order__c o = orderMap.get(ii.poNumber);
				if(o==null) o = orderAccountMap.get(ii.accountName);
				if(o!=null) {
			        if(ii.contractNumber!=null && ii.contractNumber!='') {
			        	o.Contract_Number__c = ii.contractNumber;
			            ordersToUpdate.add(o);
			        }
			        
			        if(o.Account__c!=null) {
				       List<Account> accounts = [Select Id From Account Where Id=:o.Account__c];
				       if(accounts!=null && accounts.size()>0) {
				          Account a = accounts[0];
				          a.Salesforce_Account_Number__c = ii.accountNumber;
				          accountsToUpdate.add(a);
				       }
			        }
			        
			        cloudsv__Salesforce_Invoice__c inv = new cloudsv__Salesforce_Invoice__c(Name=ii.invoiceNumber, cloudsv__External_Invoice_Id__c=ii.invoiceNumber, Account__c=o.Account__c, 
			        	                                                                    Invoice_Date__c=ii.invoiceDate, Invoice_Amount__c=ii.invoiceAmount, Service_Order__c=o.Id);
			        invoicesToUpsert.add(inv);
			        
			        // Create "Invoice" Opportunity for quickbooks sync ??
				} else {
					//Task t = new Task(Subject='Unable to locate Service Order for account '+ii.accountName,Description=ii+'');
					//insert t;
				}
			}
			Util.handleUpsertResult(Database.upsert(accountsToUpdate, false));	
		    Util.handleUpsertResult(Database.upsert(ordersToUpdate, false));
		    
		    database.upsert(invoicesToUpsert, cloudsv__Salesforce_Invoice__c.cloudsv__External_Invoice_Id__c, false);
		    
		    Map<String,cloudsv__Salesforce_Invoice__c> invoiceMap = new Map<String,cloudsv__Salesforce_Invoice__c>();
		    for(cloudsv__Salesforce_Invoice__c inv : [Select Id, Name, cloudsv__External_Invoice_Id__c From cloudsv__Salesforce_Invoice__c 
		                                              Where cloudsv__External_Invoice_Id__c IN :invoiceNumbers]) {
		    	invoiceMap.put(inv.cloudsv__External_Invoice_Id__c, inv);
		    }
	
			List<Attachment> attachmentsToInsert = new List<Attachment>();
			List<Task> tasksToInsert = new List<Task>();
			for(Util.InvoiceInfo ii : invoiceInfo.values()) {
				CHANNEL_ORDERS__Service_Order__c o = orderMap.get(ii.poNumber);
				if(o==null) o = orderAccountMap.get(ii.accountName);
				cloudsv__Salesforce_Invoice__c inv = invoiceMap.get(ii.invoiceNumber);
				System.debug('inv='+inv);
		        Attachment a = new Attachment();
		        if(inv!=null && inv.Id!=null) a.ParentId = inv.Id;
		        else {
		        	Task t = new Task(Subject='Unable to locate Service Order for account '+ii.accountName,Description=ii+'');
					insert t;
					a.ParentId = t.Id;
					//tasksToInsert.add(t);
		        }
		        a.Description = 'Invoice Details for Invoice '+ii.invoiceNumber;
		        if(o!=null) {
		        	a.Name = o.Account__r.Name+'-'+ii.invoiceDate+'.html';
		        	a.Description += ' and Order '+o.Name;
		        } else { 
		        	a.Name = ii.invoiceDate+'.html';
		        }
		        a.IsPrivate = false;
		        a.ContentType = 'text/html';
		        a.Body = ii.attachmentBody;
		        attachmentsToInsert.add(a);
			}
			//Util.handleUpsertResult(Database.upsert(tasksToInsert,false));
			Util.handleUpsertResult(Database.upsert(attachmentsToInsert, false));

	    } else {
	    	System.debug('No Salesforce OEM Invoices found!');
	    }
        
  	} catch(System.Exception e) {
  	  system.debug(logginglevel.warn,'exception processing billing email'+e);
  	  throw e;
  	}
  	
	return result; 
  }
  
  testMethod static void testParseEmail() {

	Account a = new Account(Name='Test4532423');
	insert a;
	
	CHANNEL_ORDERS__Service_Order__c o = new CHANNEL_ORDERS__Service_Order__c(Account__c=a.Id, CHANNEL_ORDERS__Customer_Org_Id__c='00D80000000aJVV', CHANNEL_ORDERS__Service_Start_Date__c=System.TODAY());
	insert o;
	
	CHANNEL_ORDERS__Service_Order__c order = [Select Id, Name From CHANNEL_ORDERS__Service_Order__c Where Id=:o.Id];

    String accountNumber = '4-446861';
    String contractNumber = '00571146';
    String invAmt = '79.78';
    String invoiceNumber = '04671999';
	String email = 'Dear Jon Jessup,\n'+
					'Please find attached a detailed invoice on your account that was due on 1/18/2013.  salesforce.com attempted to debit your account on 1/18/2013.  Please do not send payment for this invoice.\n'+ 
					'The invoice summary is as follows: \n'+
					'Account Name:                    autopartstomorrow.com\n'+
					'Account Number:                  '+accountNumber+'\n'+
					'Contract Number:                 '+contractNumber+'\n'+
					'Invoice Date:                    1/18/2013\n'+
					'Invoice Due Date:                1/18/2013\n'+
					'Invoice Number:                  '+invoiceNumber+'\n'+
					'Invoice Amount:                  USD '+invAmt+'\n'+
					'If your payment information has changed, please provide us an update by calling customer service at 415-901-8457.\n'+
					'Please do not respond to this email.\n'+
					'Sincerely, \n'+
					'The salesforce.com Billing Department \n'+
					'For answers to frequently asked billing questions, please visit our Billing FAQ at: \n'+
					'http://www.salesforce.com/company/faq.jsp \n'+
					'To log a case regarding a billing query, please click here: \n'+
					'https://www.salesforce.com/form/contact/billing-contact.jsp \n'+
					'contact customer service at 415-901-8457 for any questions.';

		 Messaging.InboundEmail.BinaryAttachment[] BinaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>();
		 Messaging.InboundEmail.BinaryAttachment ta = new Messaging.InboundEmail.BinaryAttachment();
		 ta.mimeTypeSubType = 'message/rfc822';
		 ta.filename = 'Test.html';
		 ta.body = Blob.valueOf('Purchase Order #: '+order.Name+'-');
		 BinaryAttachments.add(ta);

		 Messaging.InboundEmail emailReply = new Messaging.InboundEmail();
		 Messaging.InboundEnvelope envReply = new Messaging.InboundEnvelope();

		 emailReply.BinaryAttachments = BinaryAttachments;

		 Messaging.InboundEmail.TextAttachment[] TextAttachments = new List<Messaging.InboundEmail.TextAttachment>();
		 Messaging.InboundEmail.TextAttachment text = new Messaging.InboundEmail.TextAttachment();
		 text.body = 'Purchase Order #: '+order.Name+'-';
		 TextAttachments.add(text);
		 emailReply.TextAttachments = TextAttachments;
		 		 
		emailReply.subject = 'Do Not Send Payment: salesforce.com Invoice 04675992, Simply Bridal';
		emailReply.plainTextBody = email;
		
		ProcessSalesforceBillingEmail psbe = new ProcessSalesforceBillingEmail(); 
		psbe.handleInboundEmail(emailReply, envReply);
		
		Account a2 = [Select Id, Salesforce_Account_Number__c From Account Where Id=:a.Id];
		System.assertEquals(accountNumber, a2.Salesforce_Account_Number__c);
		
	    order = [Select Id, Name, Contract_Number__c From CHANNEL_ORDERS__Service_Order__c Where Id=:o.Id];
	    System.assertEquals(contractNumber, order.Contract_Number__c);
	    
	    cloudsv__Salesforce_Invoice__c inv = [Select Id, Name, Invoice_Amount__c, (Select Id From Attachments) From cloudsv__Salesforce_Invoice__c Where Service_Order__c=:order.Id];
	    System.assertEquals(invoiceNumber, inv.Name);
	    System.assertEquals(invAmt, inv.Invoice_Amount__c+'');
	    System.assertEquals(1, inv.Attachments.size());
  }
  
  testMethod static void testParseEmailWithoutSONumber() {

	Account a = new Account(Name='Test4532423');
	insert a;
	
	String accountName = 'autopartstomorrow.com';
	CHANNEL_ORDERS__Service_Order__c o = new CHANNEL_ORDERS__Service_Order__c(Account__c=a.Id, 
	                                                                          CHANNEL_ORDERS__Customer_Name__c=accountName, 
	                                                                          CHANNEL_ORDERS__Customer_Org_Id__c='00D80000000aJVV', 
	                                                                          CHANNEL_ORDERS__Service_Start_Date__c=System.TODAY());
	insert o;
	
	CHANNEL_ORDERS__Service_Order__c order = [Select Id, Name From CHANNEL_ORDERS__Service_Order__c Where Id=:o.Id];
    
    String accountNumber = '4-446861';
    String contractNumber = '00571146';
    String invAmt = '79.78';
    String invoiceNumber = '04671999';
	String email = 'Dear Jon Jessup,\n'+
					'Please find attached a detailed invoice on your account that was due on 1/18/2013.  salesforce.com attempted to debit your account on 1/18/2013.  Please do not send payment for this invoice.\n'+ 
					'The invoice summary is as follows: \n'+
					'Account Name:                    '+accountName+'\n'+
					'Account Number:                  '+accountNumber+'\n'+
					'Contract Number:                 '+contractNumber+'\n'+
					'Invoice Date:                    1/18/2013\n'+
					'Invoice Due Date:                1/18/2013\n'+
					'Invoice Number:                  '+invoiceNumber+'\n'+
					'Invoice Amount:                  USD '+invAmt+'\n'+
					'If your payment information has changed, please provide us an update by calling customer service at 415-901-8457.\n'+
					'Please do not respond to this email.\n'+
					'Sincerely, \n'+
					'The salesforce.com Billing Department \n'+
					'For answers to frequently asked billing questions, please visit our Billing FAQ at: \n'+
					'http://www.salesforce.com/company/faq.jsp \n'+
					'To log a case regarding a billing query, please click here: \n'+
					'https://www.salesforce.com/form/contact/billing-contact.jsp \n'+
					'contact customer service at 415-901-8457 for any questions.';

		 Messaging.InboundEmail.BinaryAttachment[] BinaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>();
		 Messaging.InboundEmail.BinaryAttachment ta = new Messaging.InboundEmail.BinaryAttachment();
		 ta.mimeTypeSubType = 'message/rfc822';
		 ta.filename = 'Test.html';
		 ta.body = Blob.valueOf('Purchase Order #: -');
		 BinaryAttachments.add(ta);

		 Messaging.InboundEmail emailReply = new Messaging.InboundEmail();
		 Messaging.InboundEnvelope envReply = new Messaging.InboundEnvelope();

		 emailReply.BinaryAttachments = BinaryAttachments;

		 Messaging.InboundEmail.TextAttachment[] TextAttachments = new List<Messaging.InboundEmail.TextAttachment>();
		 Messaging.InboundEmail.TextAttachment text = new Messaging.InboundEmail.TextAttachment();
		 text.body = 'Purchase Order #: '+order.Name+'-';
		 TextAttachments.add(text);
		 emailReply.TextAttachments = TextAttachments;
		 		 
		emailReply.subject = 'Do Not Send Payment: salesforce.com Invoice 04675992, Simply Bridal';
		emailReply.plainTextBody = email;
		
		ProcessSalesforceBillingEmail psbe = new ProcessSalesforceBillingEmail(); 
		psbe.handleInboundEmail(emailReply, envReply);
		
		Account a2 = [Select Id, Salesforce_Account_Number__c From Account Where Id=:a.Id];
		System.assertEquals(accountNumber, a2.Salesforce_Account_Number__c);
		
	    order = [Select Id, Name, Contract_Number__c From CHANNEL_ORDERS__Service_Order__c Where Id=:o.Id];
	    System.assertEquals(contractNumber, order.Contract_Number__c);
	    
	    cloudsv__Salesforce_Invoice__c inv = [Select Id, Name, Invoice_Amount__c, (Select Id From Attachments) From cloudsv__Salesforce_Invoice__c Where Service_Order__c=:order.Id];
	    System.assertEquals(invoiceNumber, inv.Name);
	    System.assertEquals(invAmt, inv.Invoice_Amount__c+'');
	    System.assertEquals(1, inv.Attachments.size());
  }  
}