class TreeSitterJavaValhalla < Formula
  desc "Tree-sitter Java grammar with JDK 28 Valhalla value classes and records"
  homepage "https://github.com/tree-sitter/tree-sitter-java"
  url "https://github.com/tree-sitter/tree-sitter-java/archive/refs/tags/v0.23.5.tar.gz"
  sha256 "cb199e0faae4b2c08425f88cbb51c1a9319612e7b96315a174a624db9bf3d9f0"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "tree-sitter-cli" => [:build, :test]

  # Matches the JDK 28 Valhalla javac parser: the JEP 401 `value` modifier as a
  # contextual keyword, JEP 513 statements before `super(...)` and `this(...)`,
  # JEP 511 `import module`, JEP 440 qualified record patterns, and JLS 8.4.1
  # annotations before a varargs ellipsis. test/corpus/valhalla.txt covers each.
  # Trees for code without these forms are unchanged. `install` regenerates src/.
  patch :DATA

  def install
    # ABI 14 matches upstream's generated v0.23.5 parser, so consumers that vendor
    # src/parser.c and src/tree_sitter/*.h can drop these files in unchanged.
    system "tree-sitter", "generate", "--abi", "14", "--js-runtime", "native"
    system ENV.cc, "-std=c11", "-O2", "-fPIC", "-shared", "-Isrc", "src/parser.c",
           "-o", lib/shared_library("libtree-sitter-java-valhalla")

    # The complete grammar crate. ast-grep-valhalla substitutes it for crates.io
    # tree-sitter-java, and ripwire compiles its src/parser.c.
    pkgshare.install "Cargo.toml", "LICENSE", "README.md", "bindings", "grammar.js",
                     "queries", "src", "test", "tree-sitter.json"
  end

  def caveats
    <<~EOS
      artagon/aitools/ast-grep-valhalla and artagon/aitools/ripwire compile this
      grammar in. To load it into another ast-grep build, register it under a
      custom name; ast-grep does not let sgconfig.yml replace built-in `java`:
        customLanguages:
          javav:
            libraryPath: #{opt_lib}/#{shared_library("libtree-sitter-java-valhalla")}
            languageSymbol: tree_sitter_java
            extensions: [java]
      ast-grep loads it only with `--custom-languages allow` or `trust`.
    EOS
  end

  test do
    (testpath/"Point.java").write <<~JAVA
      value record Point(int x, int y) {}
    JAVA
    library = lib/shared_library("libtree-sitter-java-valhalla")
    tree = shell_output("tree-sitter parse --lib-path #{library} --lang-name java #{testpath}/Point.java")
    assert_match "record_declaration", tree
    refute_match "ERROR", tree

    cp_r pkgshare, testpath/"grammar"
    system "tree-sitter", "test", "--grammar-path", testpath/"grammar"
  end
end

__END__
diff --git a/grammar.js b/grammar.js
index a97fd9f..fbf5a59 100644
--- a/grammar.js
+++ b/grammar.js
@@ -87,6 +87,9 @@ module.exports = grammar({
     [$.inferred_parameters, $.primary_expression],
     [$.argument_list, $.record_pattern_body],
     [$.yield_statement, $._reserved_identifier],
+    // An enum constant may be named by a contextual keyword such as `value`,
+    // so `@A value` stays ambiguous until the token after it.
+    [$.modifiers],
   ],
 
   word: $ => $.identifier,
@@ -521,7 +524,8 @@ module.exports = grammar({
       $.record_pattern,
     ),
     type_pattern: $ => seq($._unannotated_type, choice($.identifier, $._reserved_identifier)),
-    record_pattern: $ => seq(choice($.identifier, $._reserved_identifier, $.generic_type), $.record_pattern_body),
+    // JEP 440: the record type may be qualified, as in `Outer.Inner(int x)`.
+    record_pattern: $ => seq(choice($.identifier, $._reserved_identifier, $.generic_type, $.scoped_type_identifier), $.record_pattern_body),
     record_pattern_body: $ => seq('(', commaSep(choice($.record_pattern_component, $.record_pattern)), ')'),
     record_pattern_component: $ => choice(
       $.underscore_pattern,
@@ -571,7 +575,7 @@ module.exports = grammar({
     ),
 
     labeled_statement: $ => seq(
-      $.identifier, ':', $.statement,
+      choice($.identifier, $._reserved_identifier), ':', $.statement,
     ),
 
     assert_statement: $ => choice(
@@ -840,9 +844,15 @@ module.exports = grammar({
 
     import_declaration: $ => seq(
       'import',
-      optional('static'),
-      $._name,
-      optional(seq('.', $.asterisk)),
+      choice(
+        seq(
+          optional('static'),
+          $._name,
+          optional(seq('.', $.asterisk)),
+        ),
+        // JEP 511 (JDK 25): `import module java.base;`
+        seq('module', $._name),
+      ),
       ';',
     ),
 
@@ -871,7 +881,7 @@ module.exports = grammar({
 
     enum_constant: $ => (seq(
       optional($.modifiers),
-      field('name', $.identifier),
+      field('name', choice($.identifier, $._reserved_identifier)),
       field('arguments', optional($.argument_list)),
       field('body', optional($.class_body)),
     )),
@@ -903,6 +913,9 @@ module.exports = grammar({
       'volatile',
       'sealed',
       'non-sealed',
+      // JEP 401 (Valhalla) value classes and value records. `value` is a
+      // contextual keyword, so `_reserved_identifier` keeps it usable as a name.
+      'value',
     )),
 
     type_parameters: $ => seq(
@@ -976,10 +989,11 @@ module.exports = grammar({
       field('parameters', $.formal_parameters),
     ),
 
+    // JEP 513 (JDK 25): statements may precede `super(...)` or `this(...)`, which
+    // is how a JEP 401 value class assigns its fields before the superclass runs.
     constructor_body: $ => seq(
       '{',
-      optional($.explicit_constructor_invocation),
-      repeat($.statement),
+      repeat(choice($.statement, $.explicit_constructor_invocation)),
       '}',
     ),
 
@@ -1237,9 +1251,11 @@ module.exports = grammar({
       $.this,
     ),
 
+    // JLS 8.4.1: `UnannType {Annotation} ... Identifier`, as in `Object @Nullable ... rest`.
     spread_parameter: $ => seq(
       optional($.modifiers),
       $._unannotated_type,
+      repeat($._annotation),
       '...',
       repeat($._annotation),
       $.variable_declarator,
@@ -1276,6 +1292,7 @@ module.exports = grammar({
           'record',
           'with',
           'sealed',
+          'value',
         ),
         $.identifier,
       )),
diff --git a/test/corpus/valhalla.txt b/test/corpus/valhalla.txt
new file mode 100644
index 0000000..51f80f6
--- /dev/null
+++ b/test/corpus/valhalla.txt
@@ -0,0 +1,584 @@
+================================================================================
+Value record declaration
+================================================================================
+
+value record Point(int x, int y) {
+  Point {
+    if (x < 0) throw new IllegalArgumentException();
+  }
+}
+
+---
+
+(program
+  (record_declaration
+    (modifiers)
+    (identifier)
+    (formal_parameters
+      (formal_parameter
+        (integral_type)
+        (identifier))
+      (formal_parameter
+        (integral_type)
+        (identifier)))
+    (class_body
+      (compact_constructor_declaration
+        (identifier)
+        (block
+          (if_statement
+            (parenthesized_expression
+              (binary_expression
+                (identifier)
+                (decimal_integer_literal)))
+            (throw_statement
+              (object_creation_expression
+                (type_identifier)
+                (argument_list)))))))))
+
+================================================================================
+Value class declarations with other modifiers
+================================================================================
+
+public abstract value class Shape {}
+
+final value class Box extends Shape implements Comparable<Box> {}
+
+@Deprecated value record Tagged(String tag) {}
+
+---
+
+(program
+  (class_declaration
+    (modifiers)
+    (identifier)
+    (class_body))
+  (class_declaration
+    (modifiers)
+    (identifier)
+    (superclass
+      (type_identifier))
+    (super_interfaces
+      (type_list
+        (generic_type
+          (type_identifier)
+          (type_arguments
+            (type_identifier)))))
+    (class_body))
+  (record_declaration
+    (modifiers
+      (marker_annotation
+        (identifier)))
+    (identifier)
+    (formal_parameters
+      (formal_parameter
+        (type_identifier)
+        (identifier)))
+    (class_body)))
+
+================================================================================
+Nested and local value records
+================================================================================
+
+class Outer {
+  static value record Nested(long a) {}
+
+  sealed interface Marker permits Impl {}
+
+  public static final value record Impl(int v) implements Marker {}
+
+  void local() {
+    value record Local(int q) {}
+  }
+}
+
+---
+
+(program
+  (class_declaration
+    (identifier)
+    (class_body
+      (record_declaration
+        (modifiers)
+        (identifier)
+        (formal_parameters
+          (formal_parameter
+            (integral_type)
+            (identifier)))
+        (class_body))
+      (interface_declaration
+        (modifiers)
+        (identifier)
+        (permits
+          (type_list
+            (type_identifier)))
+        (interface_body))
+      (record_declaration
+        (modifiers)
+        (identifier)
+        (formal_parameters
+          (formal_parameter
+            (integral_type)
+            (identifier)))
+        (super_interfaces
+          (type_list
+            (type_identifier)))
+        (class_body))
+      (method_declaration
+        (void_type)
+        (identifier)
+        (formal_parameters)
+        (block
+          (record_declaration
+            (modifiers)
+            (identifier)
+            (formal_parameters
+              (formal_parameter
+                (integral_type)
+                (identifier)))
+            (class_body)))))))
+
+================================================================================
+Value as an identifier
+================================================================================
+
+enum Mode { value, other }
+
+@interface Tag {
+  String value();
+}
+
+class Identifiers {
+  int value;
+
+  @Tag(value = "x")
+  int value() {
+    int value = this.value;
+    value = value + 1;
+    value++;
+    value: for (;;) { break value; }
+    return value;
+  }
+}
+
+---
+
+(program
+  (enum_declaration
+    (identifier)
+    (enum_body
+      (enum_constant
+        (identifier))
+      (enum_constant
+        (identifier))))
+  (annotation_type_declaration
+    (identifier)
+    (annotation_type_body
+      (annotation_type_element_declaration
+        (type_identifier)
+        (identifier))))
+  (class_declaration
+    (identifier)
+    (class_body
+      (field_declaration
+        (integral_type)
+        (variable_declarator
+          (identifier)))
+      (method_declaration
+        (modifiers
+          (annotation
+            (identifier)
+            (annotation_argument_list
+              (element_value_pair
+                (identifier)
+                (string_literal
+                  (string_fragment))))))
+        (integral_type)
+        (identifier)
+        (formal_parameters)
+        (block
+          (local_variable_declaration
+            (integral_type)
+            (variable_declarator
+              (identifier)
+              (field_access
+                (this)
+                (identifier))))
+          (expression_statement
+            (assignment_expression
+              (identifier)
+              (binary_expression
+                (identifier)
+                (decimal_integer_literal))))
+          (expression_statement
+            (update_expression
+              (identifier)))
+          (labeled_statement
+            (identifier)
+            (for_statement
+              (block
+                (break_statement
+                  (identifier)))))
+          (return_statement
+            (identifier)))))))
+
+================================================================================
+Qualified record patterns
+================================================================================
+
+class Patterns {
+  int f(Object o) {
+    if (o instanceof Shape.Circle(int r)) {
+      return r;
+    }
+    return switch (o) {
+      case Shape.Pair(Shape.Circle(var a), var b) -> a;
+      default -> 0;
+    };
+  }
+}
+
+---
+
+(program
+  (class_declaration
+    (identifier)
+    (class_body
+      (method_declaration
+        (integral_type)
+        (identifier)
+        (formal_parameters
+          (formal_parameter
+            (type_identifier)
+            (identifier)))
+        (block
+          (if_statement
+            (parenthesized_expression
+              (instanceof_expression
+                (identifier)
+                (record_pattern
+                  (scoped_type_identifier
+                    (type_identifier)
+                    (type_identifier))
+                  (record_pattern_body
+                    (record_pattern_component
+                      (integral_type)
+                      (identifier))))))
+            (block
+              (return_statement
+                (identifier))))
+          (return_statement
+            (switch_expression
+              (parenthesized_expression
+                (identifier))
+              (switch_block
+                (switch_rule
+                  (switch_label
+                    (pattern
+                      (record_pattern
+                        (scoped_type_identifier
+                          (type_identifier)
+                          (type_identifier))
+                        (record_pattern_body
+                          (record_pattern
+                            (scoped_type_identifier
+                              (type_identifier)
+                              (type_identifier))
+                            (record_pattern_body
+                              (record_pattern_component
+                                (type_identifier)
+                                (identifier))))
+                          (record_pattern_component
+                            (type_identifier)
+                            (identifier))))))
+                  (expression_statement
+                    (identifier)))
+                (switch_rule
+                  (switch_label)
+                  (expression_statement
+                    (decimal_integer_literal)))))))))))
+
+================================================================================
+Annotations before a varargs ellipsis
+================================================================================
+
+class Varargs {
+  void f(Object @Nullable ... rest) {}
+}
+
+---
+
+(program
+  (class_declaration
+    (identifier)
+    (class_body
+      (method_declaration
+        (void_type)
+        (identifier)
+        (formal_parameters
+          (spread_parameter
+            (type_identifier)
+            (marker_annotation
+              (identifier))
+            (variable_declarator
+              (identifier))))
+        (block)))))
+
+================================================================================
+Value modifier with sealing and other modifiers
+================================================================================
+
+sealed abstract value class Expr permits Lit {}
+
+non-sealed abstract value class Open implements Shape {}
+
+@Deprecated value final class Mixed {}
+
+strictfp value class Legacy {}
+
+class Members {
+  private static value class Hidden {}
+
+  void local() {
+    abstract value class LocalBase {}
+  }
+}
+
+---
+
+(program
+  (class_declaration
+    (modifiers)
+    (identifier)
+    (permits
+      (type_list
+        (type_identifier)))
+    (class_body))
+  (class_declaration
+    (modifiers)
+    (identifier)
+    (super_interfaces
+      (type_list
+        (type_identifier)))
+    (class_body))
+  (class_declaration
+    (modifiers
+      (marker_annotation
+        (identifier)))
+    (identifier)
+    (class_body))
+  (class_declaration
+    (modifiers)
+    (identifier)
+    (class_body))
+  (class_declaration
+    (identifier)
+    (class_body
+      (class_declaration
+        (modifiers)
+        (identifier)
+        (class_body))
+      (method_declaration
+        (void_type)
+        (identifier)
+        (formal_parameters)
+        (block
+          (class_declaration
+            (modifiers)
+            (identifier)
+            (class_body)))))))
+
+================================================================================
+Value class constructor prologue before super
+================================================================================
+
+value class Point {
+  private final int x;
+
+  Point(int x) {
+    if (x < 0) throw new IllegalArgumentException();
+    this.x = x;
+    super();
+  }
+
+  Point() {
+    int zero = 0;
+    this(zero);
+  }
+}
+
+class Sub extends Outer.Inner {
+  Sub(Outer outer) {
+    java.util.Objects.requireNonNull(outer);
+    outer.super();
+  }
+}
+
+---
+
+(program
+  (class_declaration
+    (modifiers)
+    (identifier)
+    (class_body
+      (field_declaration
+        (modifiers)
+        (integral_type)
+        (variable_declarator
+          (identifier)))
+      (constructor_declaration
+        (identifier)
+        (formal_parameters
+          (formal_parameter
+            (integral_type)
+            (identifier)))
+        (constructor_body
+          (if_statement
+            (parenthesized_expression
+              (binary_expression
+                (identifier)
+                (decimal_integer_literal)))
+            (throw_statement
+              (object_creation_expression
+                (type_identifier)
+                (argument_list))))
+          (expression_statement
+            (assignment_expression
+              (field_access
+                (this)
+                (identifier))
+              (identifier)))
+          (explicit_constructor_invocation
+            (super)
+            (argument_list))))
+      (constructor_declaration
+        (identifier)
+        (formal_parameters)
+        (constructor_body
+          (local_variable_declaration
+            (integral_type)
+            (variable_declarator
+              (identifier)
+              (decimal_integer_literal)))
+          (explicit_constructor_invocation
+            (this)
+            (argument_list
+              (identifier)))))))
+  (class_declaration
+    (identifier)
+    (superclass
+      (scoped_type_identifier
+        (type_identifier)
+        (type_identifier)))
+    (class_body
+      (constructor_declaration
+        (identifier)
+        (formal_parameters
+          (formal_parameter
+            (type_identifier)
+            (identifier)))
+        (constructor_body
+          (expression_statement
+            (method_invocation
+              (field_access
+                (field_access
+                  (identifier)
+                  (identifier))
+                (identifier))
+              (identifier)
+              (argument_list
+                (identifier))))
+          (explicit_constructor_invocation
+            (identifier)
+            (super)
+            (argument_list)))))))
+
+================================================================================
+Primitive type patterns
+================================================================================
+
+class Patterns {
+  String f(int code, long big) {
+    if (code instanceof byte b) return "byte";
+    return switch (big) {
+      case 0L -> "zero";
+      case long l when l > 0 -> "positive";
+      default -> "negative";
+    };
+  }
+}
+
+---
+
+(program
+  (class_declaration
+    (identifier)
+    (class_body
+      (method_declaration
+        (type_identifier)
+        (identifier)
+        (formal_parameters
+          (formal_parameter
+            (integral_type)
+            (identifier))
+          (formal_parameter
+            (integral_type)
+            (identifier)))
+        (block
+          (if_statement
+            (parenthesized_expression
+              (instanceof_expression
+                (identifier)
+                (integral_type)
+                (identifier)))
+            (return_statement
+              (string_literal
+                (string_fragment))))
+          (return_statement
+            (switch_expression
+              (parenthesized_expression
+                (identifier))
+              (switch_block
+                (switch_rule
+                  (switch_label
+                    (decimal_integer_literal))
+                  (expression_statement
+                    (string_literal
+                      (string_fragment))))
+                (switch_rule
+                  (switch_label
+                    (pattern
+                      (type_pattern
+                        (integral_type)
+                        (identifier)))
+                    (guard
+                      (binary_expression
+                        (identifier)
+                        (decimal_integer_literal))))
+                  (expression_statement
+                    (string_literal
+                      (string_fragment))))
+                (switch_rule
+                  (switch_label)
+                  (expression_statement
+                    (string_literal
+                      (string_fragment))))))))))))
+
+================================================================================
+Module import declaration
+================================================================================
+
+import module java.base;
+
+import module.Foo;
+
+---
+
+(program
+  (import_declaration
+    (scoped_identifier
+      (identifier)
+      (identifier)))
+  (import_declaration
+    (scoped_identifier
+      (identifier)
+      (identifier))))
