--  The subset of CSS flexbox this engine implements, as Ada types.
--
--  Reference: CSS Flexible Box Layout Module Level 1,
--  https://www.w3.org/TR/css-flexbox-1/
--
--  Names follow the spec so students can read the spec and the code
--  side by side. Anything not listed here is out of scope for v1
--  (order, baseline alignment, writing modes, aspect-ratio).

package Boxflex.Style with SPARK_Mode, Preelaborate is

   ---------------------------------------------------------------------
   --  Dimensions: width, height, flex-basis, min/max
   ---------------------------------------------------------------------

   type Dimension_Kind is
     (Auto,      --  size from content or from the flex algorithm
      Content,   --  size from content, ignoring width/height (flex-basis only)
      Fixed,     --  an absolute length in px
      Percent);  --  a fraction of the parent's content box

   type Dimension (Kind : Dimension_Kind := Auto) is record
      case Kind is
         when Auto | Content => null;
         when Fixed   => Value    : Length   := 0.0;
         when Percent => Fraction : Boxflex.Fraction := 0.0;
      end case;
   end record;

   Auto_Dimension    : constant Dimension := (Kind => Auto);
   Content_Dimension : constant Dimension := (Kind => Content);

   function Px (Value : Length) return Dimension is
     (Kind => Fixed, Value => Value);

   function Pct (Fraction : Boxflex.Fraction) return Dimension is
     (Kind => Percent, Fraction => Fraction);

   ---------------------------------------------------------------------
   --  Enumerations, in spec order
   ---------------------------------------------------------------------

   type Flex_Direction is (Row, Row_Reverse, Column, Column_Reverse);

   type Flex_Wrap is (No_Wrap, Wrap, Wrap_Reverse);

   type Justify_Content is
     (Flex_Start, Flex_End, Center, Space_Between, Space_Around, Space_Evenly);

   type Align_Items is (Stretch, Flex_Start, Flex_End, Center, Baseline);
   --  Baseline needs a baseline per item; see Boxflex.Flex.Item.

   type Align_Self is (Auto, Stretch, Flex_Start, Flex_End, Center, Baseline);
   --  Auto means "inherit align-items from the container".

   type Align_Content is
     (Stretch, Flex_Start, Flex_End, Center, Space_Between, Space_Around);
   --  How wrapped lines share leftover cross space. Ignored for No_Wrap.

   ---------------------------------------------------------------------
   --  Box edges: margin, padding, border
   ---------------------------------------------------------------------

   type Edges is record
      Left, Top, Right, Bottom : Length := 0.0;
   end record;

   No_Edges : constant Edges := (others => 0.0);

   function Uniform (Value : Length) return Edges is
     (others => Value);

   function Horizontal (E : Edges) return Length is (E.Left + E.Right)
     with Pre => E.Left <= Length'Last - E.Right;
   function Vertical (E : Edges) return Length is (E.Top + E.Bottom)
     with Pre => E.Top <= Length'Last - E.Bottom;

   ---------------------------------------------------------------------
   --  The style of one node
   ---------------------------------------------------------------------

   type Flex_Style is record
      --  As a container (applies to this node's children):
      Direction : Flex_Direction  := Row;
      Wrap      : Flex_Wrap       := No_Wrap;
      Justify   : Justify_Content := Flex_Start;
      Align     : Align_Items     := Stretch;
      Lines     : Align_Content   := Stretch;
      Gap       : Length          := 0.0;
      Cross_Gap : Length          := 0.0;

      --  As an item (applies to this node within its parent):
      Self      : Align_Self := Auto;
      Grow      : Ratio      := 0.0;
      Shrink    : Ratio      := 1.0;
      Basis     : Dimension  := Auto_Dimension;

      --  Box:
      Width      : Dimension := Auto_Dimension;
      Height     : Dimension := Auto_Dimension;
      Min_Width  : Dimension := Auto_Dimension;
      Min_Height : Dimension := Auto_Dimension;
      Max_Width  : Dimension := Auto_Dimension;
      Max_Height : Dimension := Auto_Dimension;
      Margin     : Edges := No_Edges;
      Padding    : Edges := No_Edges;
      Border     : Edges := No_Edges;
   end record;

   Default_Style : constant Flex_Style := (others => <>);

   function Is_Row (S : Flex_Style) return Boolean is
     (S.Direction in Row | Row_Reverse);

   function Is_Reversed (S : Flex_Style) return Boolean is
     (S.Direction in Row_Reverse | Column_Reverse);

end Boxflex.Style;
