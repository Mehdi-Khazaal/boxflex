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

   function Flex_Base (I : Item) return Length is
     (if I.Basis_Definite then I.Basis else I.Content_Main);
   --  The flex base size: what the item asks for before min and max.

   function Hypothetical_Main (I : Item) return Length is
     (Clamp (Flex_Base (I), I.Min_Main, I.Max_Main));

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
   --  Max_Pos = Coord'Last - Length'Last = Length'Last - Coord'Small,
   --  so a position at Max_U or above has to become Max_Pos.
   function Pos (U : Units) return Coord is
      (if U >= Max_U then Max_Pos else Coord'(Coord'Small) * Integer (U))
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
   function Clamp_U (V, Lo, Hi : Units) return Units is
     (Units'Max (Lo, Units'Min (V, Hi)));
   --  Clamp in units: keep V inside Lo .. Hi. Lo (the min) wins if they cross.

   type Units_Array is array (Positive range <>) of Units;
   type Flag_Array is array (Positive range <>) of Boolean;

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
      One        : constant Units := Factor_Units (1.0);
      Space      : constant Units := To_Units (C.Main);
      Base       : Units_Array (Items'Range) := [others => 0];
      Target     : Units_Array (Items'Range) := [others => 0];
      Factor     : Units_Array (Items'Range) := [others => 0];
      Weight     : Units_Array (Items'Range) := [others => 0];
      Change     : Units_Array (Items'Range) := [others => 0];
      Frozen     : Flag_Array (Items'Range) := [others => False];
      Outer      : Units := 0;
      Hypo_Sum   : Units := 0;
      Initial    : Units := 0;
      Growing    : Boolean;
      Scale      : Units;
      Remaining  : Units;
      Factor_Sum : Units;
      Weight_Sum : Units;
      Running    : Units;
      Given      : Units;
      Share      : Units;
      Capped     : Units;
      Violation  : Units;
      Clamped    : Units;
   begin
      --  Margins and gaps, each item's flex base size, and its hypothetical
      --  size (Start_Sizes already put that in Main).
      for K in Items'Range loop
         Outer := Outer + To_Units (Items (K).Margin_Main_Start)
                        + To_Units (Items (K).Margin_Main_End);
         if K > Items'First then
            Outer := Outer + To_Units (C.Main_Gap);
         end if;
         Base (K)   := To_Units (Flex_Base (Items (K)));
         Target (K) := To_Units (Items (K).Main);
         Hypo_Sum   := Hypo_Sum + Target (K);
      end loop;

      --  1. Grow if the hypothetical sizes leave space, otherwise shrink.
      Growing := Outer + Hypo_Sum < Space;

      --  Each item's factor and weight. Growing shares by grow factor.
      --  Shrinking shares by shrink factor times base size, so a big item
      --  gives up more than a small one.
      for K in Items'Range loop
         Factor (K) := Factor_Units (if Growing then Items (K).Grow else Items (K).Shrink);
         Weight (K) := (if Growing then Factor (K) else Factor (K) * Base (K));
      end loop;

      --  2. Freeze items that cannot flex: factor 0, or a limit already
      --  past the base (a max below it when growing, a min above it when
      --  shrinking). They keep their hypothetical size.
      for K in Items'Range loop
         if Factor (K) = 0
           or else (if Growing then Base (K) > Target (K) else Base (K) < Target (K))
         then
            Frozen (K) := True;
         end if;
      end loop;

      --  4. Share out, freeze whoever went past a limit, repeat. Every round
      --  freezes at least one item, so one round per item is always enough.
      for Round in Items'Range loop
         --  a. Stop once every item is frozen.
         exit when (for all K in Items'Range => Frozen (K));

         --  b. Free space now: frozen items count at their target, the
         --  others at their base. Negative when shrinking. Also add up the
         --  unfrozen factors and weights.
         Remaining  := Space - Outer;
         Factor_Sum := 0;
         Weight_Sum := 0;
         for K in Items'Range loop
            if Frozen (K) then
               Remaining := Remaining - Target (K);
            else
               Remaining  := Remaining - Base (K);
               Factor_Sum := Factor_Sum + Factor (K);
               Weight_Sum := Weight_Sum + Weight (K);
            end if;
         end loop;

         --  3. The first round's free space is the spec's initial free space.
         if Round = Items'First then
            Initial := Remaining;
         end if;

         --  Factors under 1 only get that part of the initial free space,
         --  if that is smaller in size (by abs, since it can be negative).
         if Factor_Sum < One then
            Capped := Initial * Factor_Sum / One;
            if abs Capped < abs Remaining then
               Remaining := Capped;
            end if;
         end if;

         --  Safety valve: with huge sizes, Remaining * Weight could pass 64
         --  bits. Scale then divides every weight by the same number first,
         --  which keeps their proportions. In any normal layout Scale is 1.
         Scale := Weight_Sum / (Units'Last / (abs Remaining + 1)) + 1;

         --  c. Share it out by weight, using running totals: each item gets
         --  the share of everything up to and including itself, minus what
         --  was already given. Rounding never piles up, and the last item's
         --  running total is all of Remaining, so nothing is left over.
         --  d. Clamp to min and max, and add up how much the clamping moved
         --  things (the total violation).
         Violation := 0;
         Running   := 0;
         Given     := 0;
         for K in Items'Range loop
            if not Frozen (K) then
               Running    := Running + Weight (K);
               Share      := Remaining * (Running / Scale)
                               / Units'Max (Weight_Sum / Scale, 1) - Given;
               Given      := Given + Share;
               Target (K) := Base (K) + Share;
               Clamped := Clamp_U (Target (K), To_Units (Items (K).Min_Main),
                                    To_Units (Items (K).Max_Main));
               Change (K) := Clamped - Target (K);
               Violation := Violation + Change (K);
               Target (K) := Clamped;
            end if;
         end loop;

         --  e. Freeze: everyone if nothing was clamped; else only the items
         --  clamped the same way as the total (min if up, max if down).
         for K in Items'Range loop
            if not Frozen (K)
              and then (Violation = 0
                        or else (Violation > 0 and then Change (K) > 0)
                        or else (Violation < 0 and then Change (K) < 0))
            then
               Frozen (K) := True;
            end if;
         end loop;
      end loop;

      --  5. The targets are the final main sizes.
      for K in Items'Range loop
         Items (K).Main := To_Length (Target (K));
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
