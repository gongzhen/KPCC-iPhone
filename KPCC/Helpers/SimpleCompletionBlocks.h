//
//  SimpleCompletionBlocks.h
//  KPCC
//
//  Created by Fuller, Christopher on 3/11/16.
//  Copyright © 2016 SCPR. All rights reserved.
//

typedef void (^CompletionBlock)(void);
typedef void (^CompletionBlockWithValue)(id returnedObject);
typedef void (^CompletionBlockWithBool)(BOOL aBool);
