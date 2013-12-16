/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGConversationControllerCompanion.h"

@interface TGGenericConversationControllerCompanion : TGConversationControllerCompanion

- (NSString *)unreadCountPath;
- (NSString *)messagesPath;
- (NSString *)conversationPath;
- (NSString *)readMessagesPath;
- (NSString *)deletedMessagesPath;
- (NSString *)typingPath;
- (NSString *)synchronizationStatePath;
- (NSString *)blockedUsersPath;
- (NSString *)sendMessageGenericPath;
- (NSString *)sendMessagePrefix;
- (NSString *)conversationSetStatePath:(int)actionId;
- (NSString *)conversationStatePath;
- (NSString *)readHistoryPath:(int)actionId;
- (NSString *)userPath:(int)uid;
- (NSString *)userDataChangesPath;
- (NSString *)userPresencePath;
- (NSString *)historyPath:(int)mid;

@end
