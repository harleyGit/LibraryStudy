//
//  Image.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 28/11/2020.
//

#ifndef Image_h
#define Image_h

#ifndef safe_dispatch_queue_async
#define safe_dispatch_queue_async(queue, block) \
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(queue)) {\
        block();\
    } else {\
    dispatch_async(queue, block);\
    }
#endif

#ifndef safe_dispatch_main_async
#define safe_dispatch_main_async(block)  safe_dispatch_queue_async(dispatch_get_main_queue(), block)
#endif

#endif /* Image_h */
