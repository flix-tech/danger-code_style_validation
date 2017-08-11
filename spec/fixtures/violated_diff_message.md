### Code Style Check
---
Code style violations detected in the following files:
* `spec/fixtures/BadViewController.m`

Execute one of the following actions and commit again:
1. Run `clang-format` on the offending files
2. Apply the suggested patches with `git apply patch`.

#### spec/fixtures/BadViewController.m
```diff 
--- spec/fixtures/BadViewController.m
+++ spec/fixtures/BadViewController.m
@@ -1,9 +1,11 @@
-@interface ViewController (  ) @end
+@interface ViewController ()
+@end
 
 @implementation ViewController
--(void ) viewDidLoad {
+- (void)viewDidLoad
+{
     [super viewDidLoad];
-    NSLog(  @"perfect change!")   ;
+    NSLog(@"perfect change!");
 }
 
 @end

``` 
