public with sharing class ChannelOrderController {
	
	public class Order {
		public String accountId {get; set;}
		//public String orgId {get; set;}
		public Date startDate {get; set;}
		public Date agreeDate {get; set;}
		public String orderType {get; set;}
		public List<OrderLine> orderLines {get; set;}
	}

	public class OrderLine {
		public Double price {get; set;}
		public Integer qty {get; set;}
	}
	
	public ChannelOrderController(ApexPages.StandardController stdController) {
	}
	
	public PageReference createOrderFromOpportunity() {
		String id = Apexpages.currentPage().getParameters().get('id');
		List<Opportunity> opp = [Select Id, AccountId, 
		                             (Select Id, OpportunityId, SortOrder, PricebookEntryId, Quantity, TotalPrice, UnitPrice, ListPrice, 
		                                     ServiceDate, Description From OpportunityLineItems)
		                         From Opportunity Where Id=:id];
		if(opp!=null && opp.size()>0) {
			Order o = new Order();
			o.accountId = opp[0].AccountId;
			o.agreeDate = System.TODAY();
			o.orderType = 'Initial';
			o.startDate = System.TODAY();
			if(opp[0].OpportunityLineItems.size()>0) {
				List<OrderLine> olList = new List<OrderLine>();
				for(OpportunityLineItem oli : opp[0].OpportunityLineItems) {
					if(oli.UnitPrice!=500 && oli.UnitPrice!=1000) {
						OrderLine ol = new OrderLine();
						ol.qty = Integer.valueOf(oli.Quantity);
						if(ol.qty==12) ol.qty = 1;
						ol.price = oli.UnitPrice;
						if(ol.price==840) ol.price = 70;
						if(ol.price==1188) ol.price = 99;
						olList.add(ol);
					}
				}
				o.orderLines = olList;
				PageReference pr = init(o);
				if(pr!=null) return pr;
			} else {
		       ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to locate Opportunity Lines!');
		       ApexPages.addMessage(errorMessage);				
			}
		} else {
	       ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to locate Opportunity!');
	       ApexPages.addMessage(errorMessage);
		}
		return null;
	}
	
	public ChannelOrderController(Order o) {
		init(o);
	}
	
	public PageReference init(Order o) {
		Account a = [Select Id, Name, Phone, ShippingStreet, ShippingState, ShippingPostalCode, ShippingCountry, ShippingCity,  
		                    BillingStreet, BillingState, BillingPostalCode, BillingCountry, BillingCity,
		                    (Select sfLma__Subscriber_Org_ID__c From sfLma__R00N30000001JvRMEA0__r)
		             From Account Where Id=:o.accountId];
		
		String orgId = '';
		for(sfLma__License__c license : a.sfLma__R00N30000001JvRMEA0__r) {
			if(orgId=='') orgId = license.sfLma__Subscriber_Org_ID__c;
			else if(orgId!=license.sfLma__Subscriber_Org_ID__c) orgId = '';
		}
		
		String orderId  = '';
		if(orgId!='') {
			CHANNEL_ORDERS__Partner_Contract_Terms__c pt = [Select Id from CHANNEL_ORDERS__Partner_Contract_Terms__c 
			                                                Where Name='Cloud Conversion_OEM_USD'];
			
			CHANNEL_ORDERS__Service_Order__c c = new CHANNEL_ORDERS__Service_Order__c();
			c.Account__c = a.Id;
			c.CHANNEL_ORDERS__Service_Start_Date__c = o.startDate;
			//c.CHANNEL_ORDERS__Service_Order_Status__c = ;
			//c.CHANNEL_ORDERS__Service_Order_Status1__c = ;
			//c.CHANNEL_ORDERS__Product_Lines__c = ;
			c.CHANNEL_ORDERS__Partner_Contract_Rules__c = pt.Id;
			//c.CHANNEL_ORDERS__Org_Edition_Type__c = ;
			c.CHANNEL_ORDERS__Order_Type__c = o.orderType;
			//c.CHANNEL_ORDERS__Note__c = ;
			c.CHANNEL_ORDERS__I_certify__c = 'Yes';
			//c.CHANNEL_ORDERS__Error_Comment__c = ;
			//c.CHANNEL_ORDERS__Default_Contract_Length_Policy_Months__c = 12;
			//c.CHANNEL_ORDERS__Default_Auto_Renew_Policy__c = 'Always Auto Renew';
			//c.CHANNEL_ORDERS__Date_Service_Order_Received_by_SFDC__c = ;
			c.CHANNEL_ORDERS__Date_Partner_Received_Customer_Order__c = o.agreeDate;
			c.CHANNEL_ORDERS__Date_Customer_Accepted_SFDC_Svc_Agrmnt__c = o.agreeDate;
			c.CHANNEL_ORDERS__Customer_Shipping_Zip_Postal_Code__c = a.ShippingPostalCode;
			c.CHANNEL_ORDERS__Customer_Shipping_Street__c = a.ShippingStreet;
			c.CHANNEL_ORDERS__Customer_Shipping_State__c = a.ShippingState;
			c.CHANNEL_ORDERS__Customer_Shipping_Country__c = a.ShippingCountry;
			c.CHANNEL_ORDERS__Customer_Shipping_City__c = a.ShippingCity;
			c.CHANNEL_ORDERS__Customer_Org_ID__c = orgId;
			c.CHANNEL_ORDERS__Customer_Name__c = a.Name;
			c.CHANNEL_ORDERS__Customer_Billing_Zip_Postal_Code__c = a.BillingPostalCode;
			c.CHANNEL_ORDERS__Customer_Billing_Street__c = a.BillingStreet;
			c.CHANNEL_ORDERS__Customer_Billing_State__c = a.BillingState;
			c.CHANNEL_ORDERS__Customer_Billing_Country__c = a.BillingCountry;
			c.CHANNEL_ORDERS__Customer_Billing_City__c = a.BillingCity;
			//c.CHANNEL_ORDERS__Contract_Length__c = ;
			//c.CHANNEL_ORDERS__Billing_Currency__c = 'USD';
			c.CHANNEL_ORDERS__Auto_Renew__c = true;
			Database.SaveResult sr = Database.insert(c);
			System.debug(LoggingLevel.INFO, 'isSuccess='+sr.isSuccess()+' id='+sr.getId());
			orderId = sr.getId();
			if(!sr.isSuccess()) {
				String error = '';
			    for(Database.Error err : sr.getErrors()) {
					System.debug('ID='+sr.getId()+'\n');
					error += 'ID='+sr.getId()+'\n';
					System.debug('errorMessage='+err.getMessage()+'\n');
					error += 'Error='+err.getMessage() + err.getStatusCode()+'\n';
					System.debug('errorStatusCode='+err.getStatusCode()+'\n');
					for(String field : err.getFields()) {
						System.debug('fieldName='+field);
						error += 'fieldName='+field+'\n';
					}
				}
		        ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, error);
		        ApexPages.addMessage(errorMessage);
				return null;
			}
				
			// {CHANNEL_ORDERS__Order_Type__c=Reduction Order, CHANNEL_ORDERS__Default_Auto_Renew_Policy__c=Always Auto Renew, OwnerId=00530000003LCA0AAO, 
			//CHANNEL_ORDERS__Default_Contract_Length_Policy_Months__c=12, LastModifiedDate=2012-05-17 22:27:42, CHANNEL_ORDERS__Auto_Renew__c=true, 
			//CHANNEL_ORDERS__Customer_Shipping_State__c=US, CHANNEL_ORDERS__Customer_Shipping_City__c=Raleigh, CHANNEL_ORDERS__Product_Lines__c=1, 
			//CHANNEL_ORDERS__Partner_Contract_Rules__c=a1y30000000AQGKAA4, SystemModstamp=2012-08-07 22:41:33, CHANNEL_ORDERS__Billing_Currency__c=USD, 
			//Account__c=0013000000aSEoBAAW, CHANNEL_ORDERS__Service_Order_Status__c=Error, CHANNEL_ORDERS__I_certify__c=Yes, 
			//CHANNEL_ORDERS__Date_Partner_Received_Customer_Order__c=2012-05-17 00:00:00, CHANNEL_ORDERS__Customer_Org_ID__c=00DA0000000YSq8, 
			//CHANNEL_ORDERS__Error_Comment__c=This contract renewed on May 5, so we cannot process a reduction at this time., CHANNEL_ORDERS__Customer_Name__c=East Coast Shoes, 
			// CHANNEL_ORDERS__Date_Customer_Accepted_SFDC_Svc_Agrmnt__c=2012-05-17 00:00:00, CHANNEL_ORDERS__Service_Start_Date__c=2012-05-17 00:00:00, Name=SO-00000077, 
			// Num_of_Licenses__c=1.00, CHANNEL_ORDERS__Customer_Shipping_Street__c=5825 Triangle Dr., CreatedById=00530000003LCA0AAO, CreatedDate=2012-05-17 14:35:04, 
			// CHANNEL_ORDERS__Service_Order_Status1__c=Error, IsDeleted=false, CHANNEL_ORDERS__Note__c=Auto Renew and Contract Term are established on Initial orders.  All Add on orders will follow the terms as defined in your agreement with salesforce.com., 
			//Id=a2230000002HO5ZAAW, CHANNEL_ORDERS__Customer_Shipping_Zip_Postal_Code__c=27617, CHANNEL_ORDERS__Customer_Shipping_Country__c=US
	
			CHANNEL_ORDERS__Partner_Product_Catalog__c ppc = [Select Id, Name, CHANNEL_ORDERS__Product_ID__c 
			                                                  From CHANNEL_ORDERS__Partner_Product_Catalog__c 
			                                                  Where Name='Cloud Conversion Embedded Edition Admin'];
			List<CHANNEL_ORDERS__Service_Order_Detail__c> sodList = new List<CHANNEL_ORDERS__Service_Order_Detail__c>();
			sodList.add(getOrderDetail(c.Id, o.orderLines[0], ppc.Id, '1 EE User @ $'+o.orderLines[0].price+'/user/month'));
			if(o.orderLines.size()>1) {
			   CHANNEL_ORDERS__Partner_Product_Catalog__c admin = [Select Id, Name, CHANNEL_ORDERS__Product_ID__c From CHANNEL_ORDERS__Partner_Product_Catalog__c Where Name='Cloud Conversion Embedded Edition'];
			   sodList.add(getOrderDetail(c.Id, o.orderLines[1], admin.Id, '1 User @ $'+o.orderLines[1].price+'/user/month'));
			}
			insert sodList;
			
		} else {
	       ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to locate Org Id!');
	       ApexPages.addMessage(errorMessage);	
		}
		
		if(orderId!=null && orderId!='') return new PageReference('/'+orderId);
		return null;
	}

	public static CHANNEL_ORDERS__Service_Order_Detail__c getOrderDetail(Id orderId, OrderLine ol, Id prod, String description) {
		try  {
			CHANNEL_ORDERS__Service_Order_Detail__c sod = new CHANNEL_ORDERS__Service_Order_Detail__c();
			sod.CHANNEL_ORDERS__Partner_Order__c = orderId;
			sod.CHANNEL_ORDERS__Quantity__c = ol.qty;
			sod.CHANNEL_ORDERS__Product_Name__c = prod;
			sod.CHANNEL_ORDERS__Product_Line_Description__c = description;
			sod.CHANNEL_ORDERS__Product_Special_Terms__c = 'Cloud Conversion_OEM_USD';
			//sod.CHANNEL_ORDERS__Product_ID__c = catItem.Id;
			//sod.CHANNEL_ORDERS__Pricing_Type__c = 'PNR';
			//sod.CHANNEL_ORDERS__Partner_Contract_Term__c = productTerms;
			//sod.CHANNEL_ORDERS__PNR__c = 15.00;
			//sod.CHANNEL_ORDERS__Floor_Price__c = 'USD 1.00';
			//sod.CHANNEL_ORDERS__Fixed_Price__c = ol.price;
			sod.CHANNEL_ORDERS__Customer_Price__c = ol.price;
			//sod.CHANNEL_ORDERS__Currency__c = 'USD';
			//sod.CHANNEL_ORDERS__Special_Instructions__c = ;
			return sod;
	        
	        //{CHANNEL_ORDERS__PNR__c=15.00, LastModifiedById=00530000003LCA0AAO, CHANNEL_ORDERS__Product_Line_Description__c=1 User @ $70/user/month, CHANNEL_ORDERS__Currency__c=USD, 
	        //CHANNEL_ORDERS__Product_ID__c=CLDC-EMD-ADM-EE, CHANNEL_ORDERS__Partner_Order__c=a2230000000FXBGAA4, CHANNEL_ORDERS__Quantity__c=1.00, 
	        //CHANNEL_ORDERS__Product_Name__c=a1z30000000D7yYAAS, CHANNEL_ORDERS__Customer_Price__c=70.00, CHANNEL_ORDERS__Partner_Contract_Term__c=Cloud Conversion_OEM_USD, 
	        //Name=SOD-0000000041, CHANNEL_ORDERS__Product_Special_Terms__c=An Admin License is required per org and should be selected against all initial orders. 1 Admin should be ordered for every 50 User Licenses. If more than (1) Admin is required, additional admin are available., 
	        //CHANNEL_ORDERS__Floor_Price__c=USD 1.00, SystemModstamp=2011-10-03 14:58:25, CreatedById=00530000003LCA0AAO, CHANNEL_ORDERS__Pricing_Type__c=PNR, 
	        //CreatedDate=2011-10-03 14:58:25, IsDeleted=false, Id=a2130000000DOmaAAG
        
		} catch(Exception e) {
			
		}
		return null;
	}
	
    /*public static String handleSaveResult(Database.SaveResult r) {
		String error = '';
    	try {
			System.debug(LoggingLevel.INFO, 'isSuccess='+r.isSuccess()+' id='+r.getId());
			for(Database.Error err : r.getErrors()) {
				System.debug('ID='+r.getId()+'\n');
				error += 'ID='+r.getId()+'\n';
				System.debug('errorMessage='+err.getMessage()+'\n');
				error += 'Error='+err.getMessage() + err.getStatusCode()+'\n';
				System.debug('errorStatusCode='+err.getStatusCode()+'\n');
				for(String field : err.getFields()) {
					System.debug('fieldName='+field);
					error += 'fieldName='+field+'\n';
				}
			}
	      } catch( System.Exception e) {
	       	//MagentoUtil.sendErrorEmail('Exception handling upsert result for '+UserInfo.getUserName(), ' exception='+e+' cause='+e.getCause()+'message='+e.getMessage());
	        System.debug( 'Exception handling upsert result.  excpetion=' +e) ;
	        throw e;
	      }
	      return error;
    }*/

	@isTest(SeeAllData=true)
	public static void testCreateOrder1UserFromOpty() { 
		/*Opportunity opp = new Opportunity(Name='Test49324');
		opp.StageName = 'Closed';
		opp.CloseDate = System.TODAY();
		opp.AccountId = a.Id;
		insert opp;*/

		//OpportunityLineItem oppLine = new OpportunityLineItem();
		//oppLine.OpportunityId = opp.Id;
		//oppLine.Quantity = 2;
		//oppLine.UnitPrice = 80;
		//insert oppLine;
		
		Opportunity opp = [Select Id, AccountId From Opportunity Where Id=:'006E0000006kTez'];
		
		ApexPages.StandardController stdController = new ApexPages.StandardController(opp);
		ChannelOrderController coc = new ChannelOrderController(stdController);
		Apexpages.currentPage().getParameters().put('id',opp.Id);
		coc.createOrderFromOpportunity();
		
		List<CHANNEL_ORDERS__Service_Order__c> orders = [Select Id, (Select Id From CHANNEL_ORDERS__Partner_Order_Detail__r) 
		                                                 From CHANNEL_ORDERS__Service_Order__c Where Account__c=:opp.AccountId];
		System.assertEquals(1, orders.size());
		System.assertEquals(1, orders[0].CHANNEL_ORDERS__Partner_Order_Detail__r.size());
	}

	@isTest(SeeAllData=true)	
	public static void testCreateOrder1User() { 
		Account a = new Account(Name='test');
		a.ShippingStreet = 'PO Box 3656';
		a.ShippingCity = 'Park City';
		a.ShippingState = 'UT';
		a.ShippingPostalCode = '84060';
		a.ShippingCountry = 'US';
		a.Phone = '435-901-2130';
		insert a;
		
		sfLma__License__c l = new sfLma__License__c();
		l.sfLma__Subscriber_Org_ID__c = '00D429349233112';
		l.sfLma__Account__c = a.Id;
		insert l;
						
		Order o = new Order();
		o.accountId = a.Id;
		o.startDate = System.TODAY();
		o.agreeDate = System.TODAY().addDays(10);
		o.orderType = 'Initial';
		
		OrderLine ol = new OrderLine();
		ol.price = 70;
		ol.qty = 1;
		OrderLine ol2 = new OrderLine();
		ol2.price = 70;
		ol2.qty = 2;
		List<OrderLine> olList = new List<OrderLine>{ol, ol2};
		o.orderLines = olList;

		ChannelOrderController coc = new ChannelOrderController(o);
		
		List<CHANNEL_ORDERS__Service_Order__c> orders = [Select Id, (Select Id From CHANNEL_ORDERS__Partner_Order_Detail__r) 
		                                                 From CHANNEL_ORDERS__Service_Order__c Where Account__c=:a.Id];
		System.assertEquals(1, orders.size());
		System.assertEquals(2, orders[0].CHANNEL_ORDERS__Partner_Order_Detail__r.size());
	}
	
	@isTest(SeeAllData=true)	
	public static void testCreateOrderError() { 
		Account a = new Account(Name='test');
		insert a;
		
		sfLma__License__c l = new sfLma__License__c();
		l.sfLma__Subscriber_Org_ID__c = '00D429349233112';
		l.sfLma__Account__c = a.Id;
		insert l;
						
		Order o = new Order();
		o.accountId = a.Id;
		o.startDate = System.TODAY();
		o.agreeDate = System.TODAY().addDays(10);
		o.orderType = 'Initial';
		
		OrderLine ol = new OrderLine();
		ol.price = 70;
		ol.qty = 1;
		List<OrderLine> olList = new List<OrderLine>{ol};
		o.orderLines = olList;

		ChannelOrderController coc = new ChannelOrderController(o);
		
		//List<CHANNEL_ORDERS__Service_Order__c> orders = [Select Id, (Select Id From CHANNEL_ORDERS__Partner_Order_Detail__r) 
		//                                                 From CHANNEL_ORDERS__Service_Order__c Where Account__c=:a.Id];
		//System.assertEquals(1, orders.size());
		//System.assertEquals(2, orders[0].CHANNEL_ORDERS__Partner_Order_Detail__r.size());
	}
}