/*
 * Copyright 2017-2018 Alessandro Gatti - frob.it
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "SFTQuickConnectWindowController.h"
#import "SFTCommon.h"

static NSString *SFTAddressToValidURLTransformerName =
    @"SFTAddressToValidURLTransformer";

static NSCharacterSet *kASCIIDecimalCharacterSet;

static NSURL *_Nullable ConvertAddressStringToURL(NSString *_Nonnull address);

@interface SFTAddressToValidURLTransformer : NSValueTransformer

@end

@implementation SFTAddressToValidURLTransformer

+ (BOOL)allowsReverseTransformation {
  return NO;
}

+ (Class)transformedValueClass {
  return NSURL.class;
}

- (id)transformedValue:(id)value {
  return [value isKindOfClass:NSString.class]
             ? ConvertAddressStringToURL((NSString *)value)
             : nil;
}

@end

@interface SFTQuickConnectWindowController () <NSTextFieldDelegate>

@property(strong, nonatomic, nullable, readwrite) NSURL *url;

@property(weak) IBOutlet NSTextField *address;

- (IBAction)cancelConnection:(id)sender;
- (IBAction)confirmConnection:(id)sender;

- (void)terminateWithReturnCode:(NSModalResponse)response;

@end

@implementation SFTQuickConnectWindowController

+ (void)initialize {
  [NSValueTransformer setValueTransformer:[SFTAddressToValidURLTransformer new]
                                  forName:SFTAddressToValidURLTransformerName];

  kASCIIDecimalCharacterSet =
      [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
}

- (IBAction)cancelConnection:(id)sender {
  [self terminateWithReturnCode:NSModalResponseCancel];
}

- (IBAction)confirmConnection:(id)sender {
  [self terminateWithReturnCode:NSModalResponseOK];
}

- (IBAction)addressTextAction:(id)sender {
  if (self.url != nil) {
    [self confirmConnection:sender];
  }
}

- (void)terminateWithReturnCode:(NSModalResponse)response {
  [self.window.sheetParent endSheet:self.window returnCode:response];
}

- (void)controlTextDidChange:(NSNotification *)obj {
  self.url = ConvertAddressStringToURL(self.address.stringValue);
}

@end

NSURL *_Nullable ConvertAddressStringToURL(NSString *_Nonnull address) {
  NSString *trimmed = [address
      stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  if (trimmed.length == 0) {
    return nil;
  }

  NSURL *url = [NSURL URLWithString:trimmed.lowercaseString];
  if (url == nil) {
    return nil;
  }

  if (url.host == nil) {
    NSArray<NSString *> *hostAndPort =
        [trimmed componentsSeparatedByString:@":"];
    if (hostAndPort.count > 2) {
      return nil;
    }

    NSUInteger port = SFTDefaultPort;

    if (hostAndPort.count == 2) {
      if (hostAndPort[1].length == 0) {
        return nil;
      }

      for (NSUInteger index = 0; index < hostAndPort[1].length; index++) {
        if (![kASCIIDecimalCharacterSet
                characterIsMember:[hostAndPort[1] characterAtIndex:index]]) {
          return nil;
        }
      }

      NSInteger value = hostAndPort[1].integerValue;
      if ((value < 0) || (value > 65535)) {
        return nil;
      }

      port = (NSUInteger)value;
    }

    if (hostAndPort[0].length == 0) {
      return nil;
    }

    for (NSUInteger index = 0; index < hostAndPort[0].length; index++) {
      if (![NSCharacterSet.URLHostAllowedCharacterSet
              characterIsMember:[hostAndPort[0] characterAtIndex:index]]) {
        return nil;
      }
    }

    return
        [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@:%lu/",
                                                        SFTDefaultScheme,
                                                        hostAndPort[0], port]];
  }

  if ((url.scheme != nil) && ![url.scheme isEqualToString:SFTDefaultScheme]) {
    return nil;
  }

  if ((url.port != nil) && (url.port.unsignedIntValue > 65535)) {
    return nil;
  }

  return [NSURL
      URLWithString:[NSString stringWithFormat:@"%@://%@:%lu",
                                               url.scheme != nil
                                                   ? url.scheme
                                                   : SFTDefaultScheme,
                                               url.host,
                                               url.port != nil
                                                   ? url.port.unsignedIntValue
                                                   : SFTDefaultPort]];
}
