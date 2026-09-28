with Boxflex;       use Boxflex;
with Boxflex.Flex;  use Boxflex.Flex;
with Boxflex.Style; use Boxflex.Style;
with Adi.Core;      use Adi.Core;
with Adi.CSS_Styles;

package body Boxflex_Adi2 is

   package LU renames Adi.Layout_Util;
   package CS renames Adi.CSS_Styles;

   --  Float px <-> fixed point. Clamp into range rather than raise:
   --  adi2 uses Pixel_Type'Last as "no maximum".
   function To_Length (P : Pixel_Type) return Length is
     (if P <= 0.0 then 0.0
      elsif P >= Float (Length'Last) then Length'Last
      else Length (P));

   function To_Ratio (F : Float) return Ratio is
     (if F <= 0.0 then 0.0
      elsif F >= Float (Ratio'Last) then Ratio'Last
      else Ratio (F));

   function To_Px (L : Length) return Pixel_Type is (Pixel_Type (L));
   function To_Px (C : Coord)  return Pixel_Type is (Pixel_Type (C));

   --  Enumerations share names on purpose; map by 'Image would be
   --  cute, explicit case is checkable.
   function Dir (D : CS.Flex_Direction_Value) return Flex_Direction is
     (case D is
        when CS.Row => Row, when CS.Row_Reverse => Row_Reverse,
        when CS.Column => Column, when CS.Column_Reverse => Column_Reverse);

   function Wr (W : CS.Flex_Wrap_Value) return Flex_Wrap is
     (case W is
        when CS.No_Wrap => No_Wrap, when CS.Wrap => Wrap,
        when CS.Wrap_Reverse => Wrap_Reverse);

   function Ju (J : CS.Justify_Content_Value) return Justify_Content is
     (case J is
        when CS.Flex_Start => Flex_Start, when CS.Flex_End => Flex_End,
        when CS.Center => Center, when CS.Space_Between => Space_Between,
        when CS.Space_Around => Space_Around, when CS.Space_Evenly => Space_Evenly);

   function Al (A : CS.Align_Items_Value) return Align_Items is
     (case A is
        when CS.Flex_Start => Flex_Start, when CS.Flex_End => Flex_End,
        when CS.Center => Center, when CS.Baseline => Baseline,
        when CS.Stretch => Stretch);

   function Se (A : CS.Align_Self_Value) return Align_Self is
     (case A is
        when CS.Auto => Auto, when CS.Flex_Start => Flex_Start,
        when CS.Flex_End => Flex_End, when CS.Center => Center,
        when CS.Baseline => Baseline, when CS.Stretch => Stretch);

   function Li (A : CS.Align_Content_Value) return Align_Content is
     (case A is
        when CS.Flex_Start => Flex_Start, when CS.Flex_End => Flex_End,
        when CS.Center => Center, when CS.Space_Between => Space_Between,
        when CS.Space_Around => Space_Around, when CS.Stretch => Stretch);

   -------------------------
   -- Compute_Flex_Layout --
   -------------------------

   procedure Compute_Flex_Layout
     (Context  : LU.Flex_Layout_Context;
      Children : in out LU.Flex_Child_Info_Array)
   is
      Is_Row : constant Boolean := LU.Is_Row_Direction (Context.Direction);

      C : constant Container :=
        (Main      => To_Length (if Is_Row then Context.Container.Width
                                 else Context.Container.Height),
         Cross     => To_Length (if Is_Row then Context.Container.Height
                                 else Context.Container.Width),
         Direction => Dir (Context.Direction),
         Wrap      => Wr (Context.Wrap),
         Justify   => Ju (Context.Justify_Content),
         Align     => Al (Context.Align_Items),
         Lines     => Li (Context.Align_Content),
         Main_Gap  => To_Length (Context.Main_Gap),
         Cross_Gap => To_Length (Context.Cross_Gap));

      Items : Item_Array (Children'Range);
   begin
      for K in Children'Range loop
         declare
            Ch : LU.Flex_Child_Info renames Children (K);
            M  : LU.Edge_Pixels renames Ch.Margin;
         begin
            Items (K) :=
              (Grow           => To_Ratio (Ch.Flex_Grow),
               Shrink         => To_Ratio (Ch.Flex_Shrink),
               Basis          => To_Length (Ch.Flex_Basis),
               Basis_Definite => Ch.Basis_Is_Definite or else Ch.Flex_Basis /= 0.0,
               Self           => Se (Ch.Align_Self),
               Min_Main       => To_Length (Ch.Min_Main),
               Max_Main       => To_Length (Ch.Max_Main),
               Min_Cross      => To_Length (Ch.Min_Cross),
               Max_Cross      => To_Length (Ch.Max_Cross),
               Content_Main   => To_Length (Ch.Content_Main),
               Content_Cross  => To_Length (Ch.Content_Cross),
               Cross_Definite => Ch.Cross_Is_Definite,
               Baseline       => 0.0,  --  adi2 has no per-item baseline here
               Margin_Main_Start  => To_Length (if Is_Row then M.Left else M.Top),
               Margin_Main_End    => To_Length (if Is_Row then M.Right else M.Bottom),
               Margin_Cross_Start => To_Length (if Is_Row then M.Top else M.Left),
               Margin_Cross_End   => To_Length (if Is_Row then M.Bottom else M.Right),
               others         => <>);
         end;
      end loop;

      Resolve (C, Items);

      for K in Children'Range loop
         Children (K).Computed_Main      := To_Px (Items (K).Main);
         Children (K).Computed_Cross     := To_Px (Items (K).Cross);
         Children (K).Computed_Pos_Main  := To_Px (Items (K).Pos_Main);
         Children (K).Computed_Pos_Cross := To_Px (Items (K).Pos_Cross);
      end loop;
   end Compute_Flex_Layout;

end Boxflex_Adi2;
