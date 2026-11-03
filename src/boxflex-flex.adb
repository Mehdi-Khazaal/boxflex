package body Boxflex.Flex with SPARK_Mode is

   --  Sums over many items can exceed Coord. Accumulate in units of
   --  Coord'Small in a wide integer instead.
   type Units is range -2 ** 62 .. 2 ** 62 - 1;

   --  Constant specifying how many units make up one pixel coordinate.
   Units_Per_Pixel : constant Units :=
      Units (1.0 / Coord'Small);

   function To_Units (L : Length) return Units is
     (Units (Long_Long_Integer (L) * Long_Long_Integer (Units_Per_Pixel)));

   function Whole_Pixels (U : Units) return Long_Long_Integer is
      (Long_Long_Integer (U / Units_Per_Pixel))
      with
         Pre => U >= 0;

   function Fractional_Pixels (U : Units) return Integer is
      (Integer (U rem Units_Per_Pixel))
      with
         Pre => U >= 0;

   function Clamp (V, Lo, Hi : Length) return Length is
      (Length'Max (Lo, Length'Min (V, Hi)));

   --  Helper function to determine stretch eligibility
   function Wants_Stretch (C : Container; I : Item) return Boolean is
      --  Stretch is only eligible if the cross size is not explicitly specified
      --  (not I.Cross_Definite) and either the item explicitly requests to stretch or
      --  the item inherits the stretch value from the container
      --  (I.Self = Auto and C.Align = Stretch).
      (not I.Cross_Definite and then (I.Self = Stretch
      or else (I.Self = Auto and then C.Align = Stretch)));

   --  Implementation for Stretched_Cross
   function Stretched_Cross (Line_Cross : Length; I : Item) return Length
   is
      --  Convert the working variables to units
      Line_U : constant Units := To_Units (Line_Cross);
      Start_U : constant Units := To_Units (I.Margin_Cross_Start);
      End_U : constant Units := To_Units (I.Margin_Cross_End);

      --  Calculate the stretched cross size in units
      Available_U : constant Units := Units'Max (0, Line_U - Start_U - End_U);
      --  Convert this back to Length and clamp it to the item's min and max cross sizes
      Available_L : constant Length := Length'(Length'Small) * Integer (Available_U);
   begin
      return Clamp (Available_L, I.Min_Cross, I.Max_Cross);
   end Stretched_Cross;

   -----------------------
   -- Hypothetical_Main --
   -----------------------

   function Hypothetical_Main (I : Item) return Length is
     (Clamp ((if I.Basis_Definite then I.Basis else I.Content_Main),
             I.Min_Main, I.Max_Main));

   ----------------
   -- Form_Lines --
   ----------------

   procedure Form_Lines
     (C     : Container;
      Items : Item_Array;
      Lines : out Line_Array;
      Count : out Natural)
   is
      Limit : constant Units := To_Units (C.Main);
      Gap   : constant Units := To_Units (C.Main_Gap);
      Used  : Units := 0;
      Outer : Units;
   begin
      Lines := [others => (First => 0, Last => 0)];
      Count := 0;

      for K in Items'Range loop
         pragma Loop_Invariant (Count <= K - Items'First);
         pragma Loop_Invariant (Count = 0 or else Lines (Count).Last = K - 1);
         pragma Loop_Invariant (Used >= 0);

         Outer := To_Units (Items (K).Margin_Main_Start)
                  + To_Units (Hypothetical_Main (Items (K)))
                  + To_Units (Items (K).Margin_Main_End);

         if Count = 0
           or else (C.Wrap /= No_Wrap and then Used + Gap + Outer > Limit)
         then
            --  Open a new line. A line always takes at least one item.
            Count := Count + 1;
            Lines (Count) := (First => K, Last => K);
            Used := Outer;
         else
            Lines (Count).Last := K;
            Used := Used + Gap + Outer;
         end if;
      end loop;
   end Form_Lines;

   -------------
   -- Resolve --
   -------------

   --  PLACEHOLDER. Packs items in order at their hypothetical main
   --  size, Flex_Start on both axes, no grow, no shrink, no wrap, no
   --  reversal. Replace with steps 1 to 7 of the spec (see the
   --  package spec and ARCHITECTURE.md).

   procedure Resolve (C : Container; Items : in out Item_Array) is
      Cursor : Units := 0;
      Gap    : constant Units := To_Units (C.Main_Gap);
      Max_U  : constant Units := To_Units (Length'Last);
      --  Max_Pos = Coord'Last - Length'Last, and Length'Last = 2**22,
      --  so a position of at most Length'Last (as a Coord) is safe.

      function Pos (U : Units) return Coord is
         (if U > Max_U then Max_Pos else
            Coord (Whole_Pixels (U)) + Coord'(Coord'Small) * Fractional_Pixels (U))
         with
            Pre => U >= 0,
            Post =>
               Pos'Result >= 0.0
               and then Pos'Result <= Max_Pos
               and then
               (if U < Max_U then
                  To_Units (Pos'Result) = U
               else
                  Pos'Result = Max_Pos);
      --  Convert from Units to Coord, saturating at Max_Pos.

   begin
      for K in Items'Range loop
         pragma Loop_Invariant (Cursor >= 0);
         pragma Loop_Invariant
           (for all J in Items'First .. K - 1 =>
              Inputs_Unchanged (Items'Loop_Entry (J), Items (J))
              and then Placed_In_Range (Items (J)));
         pragma Loop_Invariant
           (for all J in K .. Items'Last => Items (J) = Items'Loop_Entry (J));

         Items (K).Main  := Hypothetical_Main (Items (K));

         --  Cross is set to the stretched cross size if eligible, otherwise
         --  it is set to the hypothetical cross size (clamped to the item's
         --  min and max cross sizes).
         if C.Wrap = No_Wrap and then Wants_Stretch (C, Items (K)) then
            Items (K).Cross := Stretched_Cross (C.Cross, Items (K));
         else
            Items (K).Cross := Clamp (Items (K).Content_Cross,
                                       Items (K).Min_Cross,
                                       Items (K).Max_Cross);
         end if;

         Cursor := Cursor + To_Units (Items (K).Margin_Main_Start);
         Items (K).Pos_Main  := Pos (Cursor);
         Items (K).Pos_Cross := Pos (To_Units (Items (K).Margin_Cross_Start));

         Cursor := Cursor + To_Units (Items (K).Main)
                   + To_Units (Items (K).Margin_Main_End) + Gap;
      end loop;
   end Resolve;
end Boxflex.Flex;
