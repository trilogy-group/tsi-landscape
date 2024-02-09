public with sharing class CreateQuoteLines {

    public class CreateQuoteInput {
        @InvocableVariable(label='Product ID')
        public String productId;
        @InvocableVariable(label='Main Product Line ID')
        public String mainProductLineId;
        @InvocableVariable(label='Quote Id')
        public String quoteId;
        @InvocableVariable(label='Next Quote Line Number for Bundled')
        public Integer nextBundledQuoteLineNumber;
        @InvocableVariable(label='Subscription Term')
        public Integer subscriptionTerm;
        @InvocableVariable(label='Currency ISO Code')
        public String currencyIsoCode;
        @InvocableVariable(label='Subscription Items')
        public List<SubscriptionItem> subscriptionItems;
        @InvocableVariable(label='New Success Level')
        public String newSuccessLevel;
    }

    @InvocableMethod(label='Create Quote Lines From Subscription Items' description='Create SBQQ__QuoteLine__c records')
    public static List<String> createQuoteFromProductAndSubscriptionItems(List<CreateQuoteInput> input) {
        Integer nextBundledQuoteLineNumber = input[0].nextBundledQuoteLineNumber;
        Integer nextBundleQuoteLineNumber = 2;
        // Get the product options
        List<SBQQ__ProductOption__c> productOptions = [
            SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.ProductCode, SBQQ__OptionalSKU__r.Description,
            SBQQ__OptionalSKU__r.Min_Quantity__c, SBQQ__OptionalSKU__r.Max_Quantity__c,
            SBQQ__OptionalSKU__r.SBQQ__PricingMethod__c
            FROM SBQQ__ProductOption__c WHERE SBQQ__ConfiguredSKU__c = :input[0].productId
            AND SBQQ__Bundled__c = false
        ];

        // Create quote lines for the subscription items
        List<SBQQ__QuoteLine__c> newQuoteLines = new List<SBQQ__QuoteLine__c>();
        List<SBQQ__QuoteLine__c> bundleOptions = new List<SBQQ__QuoteLine__c>();
        List<Id> bundleProductIds = new List<Id>();
        if(input[0].subscriptionItems!=null && !input[0].subscriptionItems.isEmpty()) {
            for (SubscriptionItem subscriptionItem : input[0].subscriptionItems) {
                if (subscriptionItem.isMainItem) {
                    continue;
                }
    
                String newBundleCode = replaceSuccessLevel(subscriptionItem.bundleCode, input[0].newSuccessLevel);
                SBQQ__ProductOption__c productOption = findByCode(productOptions, newBundleCode);
                Boolean bundle = false;
                Integer nextNumber = 0;
                if (productOption != null) {
                    nextNumber = nextBundleQuoteLineNumber;
                    nextBundleQuoteLineNumber++;
                    bundle = true;
                } else {
                    String newItemCode = replaceSuccessLevel(subscriptionItem.code, input[0].newSuccessLevel);
                    productOption = findByCode(productOptions, newItemCode);
                    if (productOption == null) {
                        // product option not found, not adding this product
                        continue;
                    }
                    nextNumber = nextBundledQuoteLineNumber;
                    nextBundledQuoteLineNumber++;
                }
    
                Decimal quantity = subscriptionItem.quantity;
                if (productOption.SBQQ__OptionalSKU__r.Min_Quantity__c != null
                    && productOption.SBQQ__OptionalSKU__r.Min_Quantity__c > quantity) {
                    quantity = productOption.SBQQ__OptionalSKU__r.Min_Quantity__c;
                } else if (productOption.SBQQ__OptionalSKU__r.Max_Quantity__c != null
                            && productOption.SBQQ__OptionalSKU__r.Max_Quantity__c < quantity) {
                    quantity = productOption.SBQQ__OptionalSKU__r.Max_Quantity__c;
                }
                SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
                    SBQQ__Quote__c = input[0].quoteId,
                    SBQQ__Product__c = productOption.SBQQ__OptionalSKU__c,
                    SBQQ__Number__c = nextNumber,
                    SBQQ__ProductOption__c = productOption.Id,
                    SBQQ__PackageProductDescription__c = productOption.SBQQ__OptionalSKU__r.Description,
                    SBQQ__Quantity__c = quantity,
                    SBQQ__PricingMethod__c = productOption.SBQQ__OptionalSKU__r.SBQQ__PricingMethod__c,
                    CurrencyIsoCode = input[0].currencyIsoCode,
                    SBQQ__Bundle__c = bundle,
                    SBQQ__Bundled__c = !bundle,
                    SBQQ__OptionLevel__c = 1,
                    SBQQ__RequiredBy__c = input[0].mainProductLineId,
                    SBQQ__SubscriptionTerm__c = input[0].subscriptionTerm,
                    SBQQ__OptionType__c = 'Accessory'
                );
                // Setting 100 to Option discount, as this will make this quote line to have 0 price and not be part of price distribution by CPQ Target Customer Amount field
                if (subscriptionItem.ARR == 0) {
                    quoteLine.SBQQ__OptionDiscount__c = 100;
                }
                newQuoteLines.add(quoteLine);
                if (bundle) {
                    bundleOptions.add(quoteLine);
                    bundleProductIds.add(quoteLine.SBQQ__Product__c);
                } else if (subscriptionItem.supportCode != null) {
                    // if it's not bundle, we need to add the support item if item is product item
                    String newItemCode = replaceSuccessLevel(subscriptionItem.supportCode, input[0].newSuccessLevel);
                    productOption = findByCode(productOptions, newItemCode);
                    if (productOption == null) {
                        // product option not found, not adding this support item
                        continue;
                    }
                    quoteLine = new SBQQ__QuoteLine__c(
                        SBQQ__Quote__c = input[0].quoteId,
                        SBQQ__Product__c = productOption.SBQQ__OptionalSKU__c,
                        SBQQ__Number__c = nextBundledQuoteLineNumber,
                        SBQQ__ProductOption__c = productOption.Id,
                        SBQQ__PackageProductDescription__c = productOption.SBQQ__OptionalSKU__r.Description,
                        SBQQ__Quantity__c = quantity,
                        SBQQ__PricingMethod__c = productOption.SBQQ__OptionalSKU__r.SBQQ__PricingMethod__c,
                        CurrencyIsoCode = input[0].currencyIsoCode,
                        SBQQ__Bundle__c = bundle,
                        SBQQ__Bundled__c = !bundle,
                        SBQQ__OptionLevel__c = 1,
                        SBQQ__RequiredBy__c = input[0].mainProductLineId,
                        SBQQ__SubscriptionTerm__c = input[0].subscriptionTerm,
                        SBQQ__OptionType__c = 'Accessory'
                    );
                    // Setting 100 to Option discount, as this will make this quote line to have 0 price and not be part of price distribution by CPQ Target Customer Amount field
                    if (subscriptionItem.ARR == 0) {
                        quoteLine.SBQQ__OptionDiscount__c = 100;
                    }
                    newQuoteLines.add(quoteLine);
                    nextBundledQuoteLineNumber++;
                }
            }
        }
        if(newQuoteLines!=null && !newQuoteLines.isEmpty()) {
            insert newQuoteLines;
        }
        
        List<Id> quoteLineIds = new List<Id>((new Map<Id, SBQQ__QuoteLine__c>(newQuoteLines)).keySet());
        newQuoteLines.clear();

        // For bundles it's necessary to add the quote lines for the included items
        productOptions = [SELECT Id, SBQQ__ConfiguredSKU__c, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.ProductCode,
                          SBQQ__OptionalSKU__r.Description, SBQQ__OptionalSKU__r.Min_Quantity__c,
                          SBQQ__OptionalSKU__r.Max_Quantity__c, SBQQ__OptionalSKU__r.SBQQ__PricingMethod__c
                          FROM SBQQ__ProductOption__c WHERE SBQQ__ConfiguredSKU__c in :bundleProductIds
                          AND SBQQ__Bundled__c = true AND SBQQ__Type__c = 'Component'];
        for (SBQQ__QuoteLine__c bundle : bundleOptions) {
            List<SBQQ__ProductOption__c> options = findByConfiguredSKU(productOptions, bundle.SBQQ__Product__c);
            for (SBQQ__ProductOption__c option : options) {
                SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
                    SBQQ__Quote__c = input[0].quoteId,
                    SBQQ__Product__c = option.SBQQ__OptionalSKU__c,
                    SBQQ__Number__c = nextBundledQuoteLineNumber,
                    SBQQ__ProductOption__c = option.Id,
                    SBQQ__PackageProductDescription__c = option.SBQQ__OptionalSKU__r.Description,
                    SBQQ__BundledQuantity__c = 1,
                    SBQQ__PricingMethod__c = option.SBQQ__OptionalSKU__r.SBQQ__PricingMethod__c,
                    CurrencyIsoCode = input[0].currencyIsoCode,
                    SBQQ__Bundle__c = false,
                    SBQQ__Bundled__c = true,
                    SBQQ__OptionLevel__c = 2,
                    SBQQ__RequiredBy__c = bundle.Id,
                    SBQQ__SubscriptionTerm__c = input[0].subscriptionTerm,
                    SBQQ__OptionType__c = 'Component'
                );
                newQuoteLines.add(quoteLine);
                nextBundledQuoteLineNumber++;
            }
        }
        insert newQuoteLines;
        quoteLineIds.addAll(new List<Id>((new Map<Id, SBQQ__QuoteLine__c>(newQuoteLines)).keySet()));

        return new List<String>{'QuoteLineIds created: ' + String.join(quoteLineIds,' - ')};
    }

    private static SBQQ__ProductOption__c findByCode(List<SBQQ__ProductOption__c> productOptions, String codeToFind) {
        if (codeToFind == null) {
            return null;
        }
        for(SBQQ__ProductOption__c option : productOptions) {
            if(option.SBQQ__OptionalSKU__r.ProductCode == codeToFind) {
                return option;
            }
        }
        return null;
    }

    private static List<SBQQ__ProductOption__c> findByConfiguredSKU(List<SBQQ__ProductOption__c> productOptions,
        String bundleId) {
        List<SBQQ__ProductOption__c> options = new List<SBQQ__ProductOption__c>();
        for(SBQQ__ProductOption__c option : productOptions) {
            if(option.SBQQ__ConfiguredSKU__c == bundleId) {
                options.add(option);
            }
        }
        return options;
    }

    private static String replaceSuccessLevel(String code, String newSuccessLevel) {
        if (code == null) {
            return null;
        }
        List<String> codeParts = code.split('-');
        List<String> successLevelCodes = new List<String>{'SIL','GOL','PLA'};
        if (codeParts.size() > 4 && successLevelCodes.contains(codeParts[4])) {
            codeParts.set(4, newSuccessLevel);
            return String.join(codeParts,'-');
        } else if (codeParts.size() == 4 && successLevelCodes.contains(codeParts[3])) {
            codeParts.set(3, newSuccessLevel);
            return String.join(codeParts,'-');
        }
        return code;
    }
}