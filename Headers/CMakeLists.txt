target_sources(objc
        PUBLIC FILE_SET HEADERS
        BASE_DIRS .
        FILES
        objc/Availability.h
        objc/Object.h
        objc/Protocol.h
        objc/blocks_private.h
        objc/blocks_runtime.h
        objc/capabilities.h
        objc/developer.h
        objc/encoding.h
        objc/hooks.h
        objc/message.h
        objc/objc-api.h
        objc/objc-arc.h
        objc/objc-auto.h
        objc/objc-class.h
        objc/objc-exception.h
        objc/objc-runtime.h
        objc/objc-visibility.h
        objc/objc.h
        objc/runtime-deprecated.h
        objc/runtime.h
        objc/slot.h
        # Compat headers
        Block.h
        Block_private.h)