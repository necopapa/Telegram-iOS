#import "TLDecryptedMessage.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLDecryptedMessageMedia.h"

@implementation TLDecryptedMessage

@synthesize random_id = _random_id;
@synthesize random_bytes = _random_bytes;
@synthesize from_id = _from_id;
@synthesize date = _date;
@synthesize message = _message;
@synthesize media = _media;

- (int32_t)TLconstructorSignature
{
    TGLog(@"constructorSignature is not implemented for base type");
    return 0;
}

- (int32_t)TLconstructorName
{
    TGLog(@"constructorName is not implemented for base type");
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TGLog(@"TLbuildFromMetaObject is not implemented for base type");
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
    TGLog(@"TLfillFieldsWithValues is not implemented for base type");
}


@end

@implementation TLDecryptedMessage$decryptedMessage : TLDecryptedMessage


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x17c9db31;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xf5633b38;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLDecryptedMessage$decryptedMessage *object = [[TLDecryptedMessage$decryptedMessage alloc] init];
    object.random_id = metaObject->getInt64(0xca5a160a);
    object.random_bytes = metaObject->getBytes(0xaf157b8d);
    object.from_id = metaObject->getInt32(0xf39a7861);
    object.date = metaObject->getInt32(0xb76958ba);
    object.message = metaObject->getString(0xc43b7853);
    object.media = metaObject->getObject(0x598de2e7);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.random_id;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xca5a160a, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.random_bytes;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xaf157b8d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.from_id;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xf39a7861, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.date;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xb76958ba, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.message;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xc43b7853, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.media;
        values->insert(std::pair<int32_t, TLConstructedValue>(0x598de2e7, value));
    }
}


@end

@implementation TLDecryptedMessage$decryptedMessageForwarded : TLDecryptedMessage

@synthesize fwd_from_id = _fwd_from_id;
@synthesize fwd_date = _fwd_date;

- (int32_t)TLconstructorSignature
{
    return (int32_t)0x2e27aa61;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x41754fe2;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLDecryptedMessage$decryptedMessageForwarded *object = [[TLDecryptedMessage$decryptedMessageForwarded alloc] init];
    object.random_id = metaObject->getInt64(0xca5a160a);
    object.random_bytes = metaObject->getBytes(0xaf157b8d);
    object.fwd_from_id = metaObject->getInt32(0x3d97b085);
    object.fwd_date = metaObject->getInt32(0xb08aba8b);
    object.from_id = metaObject->getInt32(0xf39a7861);
    object.date = metaObject->getInt32(0xb76958ba);
    object.message = metaObject->getString(0xc43b7853);
    object.media = metaObject->getObject(0x598de2e7);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.random_id;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xca5a160a, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.random_bytes;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xaf157b8d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.fwd_from_id;
        values->insert(std::pair<int32_t, TLConstructedValue>(0x3d97b085, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.fwd_date;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xb08aba8b, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.from_id;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xf39a7861, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.date;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xb76958ba, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.message;
        values->insert(std::pair<int32_t, TLConstructedValue>(0xc43b7853, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.media;
        values->insert(std::pair<int32_t, TLConstructedValue>(0x598de2e7, value));
    }
}


@end

