package body Boxflex.Flex with SPARK_Mode is

   --  Sums over many items can exceed Coord. Accumulate in units of
   --  Coord'Small in a wide integer instead.
   type Units is range -2 ** 62 .. 2 ** 62 - 1;

   function To_Units (L : Length) return Units is
     (Units (L / Length'(Length'Small)));

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

   Max_U  : constant Units := To_Units (Length'Last);
   --  Max_Pos = Coord'Last - Length'Last, and Length'Last = 2**22,
   --  so a position of at most Length'Last (as a Coord) is safe.
   function Pos (U : Units) return Coord is
      (if U > Max_U then Max_Pos else Coord'(Coord'Small) * Integer (U))
      with Pre => U >= 0;
   --  Units to Coord, saturating at Max_Pos.

   Units_Per_Px : constant Units := Units (1.0 / Length'Small);
   --  How many units make one pixel (256 today). Worked out, never typed in.

   function To_Length (U : Units) return Length is
     (Length (U / Units_Per_Px) + Length'(Length'Small) * Integer (U mod Units_Per_Px))
     with Pre => U >= 0 and then U <= Max_U;
   --  Units back to a Length. Whole pixels stay in Units; only the leftover
   --  fraction (always under Units_Per_Px) goes through Integer, so this
   --  also works where Integer is only 16 bits.

   function Factor_Units (R : Ratio) return Units is
     (Units (R / Ratio'(Ratio'Small)));
   --  A grow or shrink factor counted in steps of Ratio'Small, so 1.0 = 1024.

   procedure Start_Sizes (Items : in out Item_Array);
   procedure Flex_Lengths (C : Container; Items : in out Item_Array);
   procedure Cross_Sizes (C : Container; Items : in out Item_Array);
   procedure Main_Positions (C : Container; Items : in out Item_Array);
   procedure Cross_Positions (C : Container; Items : in out Item_Array);

   procedure Start_Sizes (Items : in out Item_Array) is
   begin
      for K in Items'Range loop
         Items (K).Main  := Hypothetical_Main (Items (K));
         Items (K).Cross := Clamp (Items (K).Content_Cross,
                                    Items (K).Min_Cross,
                                    Items (K).Max_Cross);
      end loop;
   end Start_Sizes;

   procedure Flex_Lengths (C : Container; Items : in out Item_Array) is
      Gap        : constant Units := To_Units (C.Main_Gap);
      Used       : Units := 0;
      Total_Grow : Units := 0;
      Free       : Units;
      Share      : Units;
   begin
      --  1. Space the items take now, and the sum of their grow factors.
      for K in Items'Range loop
         Used := Used + To_Units (Items (K).Margin_Main_Start)
                      + To_Units (Items (K).Main)
                      + To_Units (Items (K).Margin_Main_End);
         if K > Items'First then
            Used := Used + Gap;
         end if;
         Total_Grow := Total_Grow + Factor_Units (Items (K).Grow);
      end loop;

      --  2. Space left over. Nothing to share if none is left or nobody grows.
      Free := To_Units (C.Main) - Used;
      if Free <= 0 or else Total_Grow = 0 then
         return;
      end if;

      --  3. Each item gets Free * (its grow / total grow). If the factors add
      --  up to less than 1, divide by 1 instead, so only that part of the
      --  free space is handed out (CSS spec, section 9.7).
      for K in Items'Range loop
         Share := Free * Factor_Units (Items (K).Grow)
                  / Units'Max (Total_Grow, Factor_Units (1.0));
         Items (K).Main := To_Length (To_Units (Items (K).Main) + Share);
      end loop;
   end Flex_Lengths;

   procedure Cross_Sizes (C : Container; Items : in out Item_Array) is
   begin
      for K in Items'Range loop
         if C.Wrap = No_Wrap and then Wants_Stretch (C, Items (K)) then
            Items (K).Cross := Stretched_Cross (C.Cross, Items (K));
         end if;
      end loop;
   end Cross_Sizes;

   procedure Main_Positions (C : Container; Items : in out Item_Array) is
      Cursor : Units := 0;
      Gap : constant Units := To_Units (C.Main_Gap);
   begin
      for K in Items'Range loop
         pragma Loop_Invariant (Cursor >= 0);
         pragma Loop_Invariant
           (for all J in Items'First .. K - 1 =>
              Inputs_Unchanged (Items'Loop_Entry (J), Items (J))
              and then Placed_In_Range (Items (J)));
         pragma Loop_Invariant
           (for all J in K .. Items'Last => Items (J) = Items'Loop_Entry (J));

         Cursor := Cursor + To_Units (Items (K).Margin_Main_Start);
         Items (K).Pos_Main  := Pos (Cursor);

         Cursor := Cursor + To_Units (Items (K).Main)
                   + To_Units (Items (K).Margin_Main_End) + Gap;
      end loop;
   end Main_Positions;

   procedure Cross_Positions (C : Container; Items : in out Item_Array) is
      pragma Unreferenced (C);
   begin
      for K in Items'Range loop
         Items (K).Pos_Cross := Pos (To_Units (Items (K).Margin_Cross_Start));
      end loop;
   end Cross_Positions;

   -------------
   -- Resolve --
   -------------

   --  One call per step of the algorithm. See the package spec.

   procedure Resolve (C : Container; Items : in out Item_Array) is
   begin
      Start_Sizes (Items);
      Flex_Lengths (C, Items);
      Cross_Sizes (C, Items);
      Main_Positions (C, Items);
      Cross_Positions (C, Items);
   end Resolve;
end Boxflex.Flex;
