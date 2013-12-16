/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "ActionStage.h"

#import "TGUser.h"
#import "TGPhonebookContact.h"

@interface TGProfileController : TGViewController <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic, strong) NSString *overrideFirstName;
@property (nonatomic, strong) NSString *overrideLastName;

- (id)initWithUid:(int)uid preferNativeContactId:(int)preferNativeContactId encryptedConversationId:(int64_t)encryptedConversationId;
- (void)switchToUid:(int)uid;

- (int)uid;

- (id)initWithPhonebookContact:(TGPhonebookContact *)phonebookContact;
- (id)initWithCreateNewContact:(TGUser *)user watcherHandle:(ASHandle *)watcherHandle;
- (id)initWithAddToExistingContact:(TGUser *)user phonebookContact:(TGPhonebookContact *)phonebookContact phoneNumber:(NSString *)phoneNumber addingUid:(int)addingUid watcherHandle:(ASHandle *)watcherHandle;
- (id)initWithAddToExistingPhonebookContact:(TGPhonebookContact *)phonebookContact phoneNumber:(NSString *)phoneNumber addingUid:(int)addingUid watcherHandle:(ASHandle *)watcherHandle;

- (void)_updateProfileImage:(UIImage *)image;

@end
