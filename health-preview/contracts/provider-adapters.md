# Provider Adapter Map

The CRM should keep providers swappable.

| Capability | Interface | Status |
|---|---|---|
| ACA plan data | MarketplaceAdapter | Contract defined |
| ACA provider/drug checks | MarketplaceAdapter | Contract defined |
| Email | EmailAdapter | Contract defined |
| Voice | VoiceAdapter | Contract defined |
| SMS | SmsAdapter | Contract defined |
| Fax | FaxAdapter | Contract defined |
| Carrier product sync | CarrierAdapter | Contract defined |
| Carrier contracting | CarrierAdapter | Contract defined |
| Commission statements | CarrierAdapter | Contract defined |

No provider credentials belong in frontend source.
