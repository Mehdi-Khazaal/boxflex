--  Regression tests for justify-content on the m1 branch.
--  Exercise Boxflex.Flex.Resolve through its public API, not private helpers.
--  These tests assume non-wrapping, forward main-axis placement.
--  Remainder assertions expect earliest conceptual gaps to receive extras.

with Ada.Text_IO;     use Ada.Text_IO;
with Boxflex;         use Boxflex;
with Boxflex.Flex;    use Boxflex.Flex;
with Boxflex.Style;   use Boxflex.Style;

procedure Justify_Regression (Failures : in out Natural) is

   type Coord_Array is array (Positive range <>) of Coord;

   procedure Check (Name : String; Condition : Boolean) is
   begin
      if Condition then
         Put_Line ("PASS  justify: " & Name);
      else
         Put_Line ("FAIL  justify: " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   function Fixed_Item (Size : Length) return Item is
     (Basis          => Size,
      Basis_Definite => True,
      Content_Cross  => 10.0,
      Cross_Definite => True,
      others         => <>);

   procedure Check_Positions
      (Name : String; Items : Item_Array; Expected : Coord_Array)
   is
      Matches : Boolean := Items'Length = Expected'Length;
   begin
      if Matches then
         for K in Items'Range loop
            if Items (K).Pos_Main /= Expected (Expected'First + K - Items'First) then
               Matches := False;
            end if;
         end loop;
      end if;

      Check (Name, Matches);

      if not Matches and then Items'Length = Expected'Length then
         for K in Items'Range loop
            declare
               Wanted : constant Coord :=
                  Expected (Expected'First + K - Items'First);
            begin
               if Items (K).Pos_Main /= Wanted then
                  Put_Line
                     ("  index" & Integer'Image (K)
                      & ": expected" & Coord'Image (Wanted)
                      & ", got" & Coord'Image (Items (K).Pos_Main));
               end if;
            end;
         end loop;
      end if;
   end Check_Positions;

   procedure Test_All_Modes is
      C  : Container := (Main => 300.0, Cross => 100.0, others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (50.0)];
   begin
      for Mode in Justify_Content loop
         C.Justify := Mode;
         Resolve (C, It);
         case Mode is
            when Flex_Start =>
               Check_Positions ("flex-start", It, [0.0, 50.0, 100.0]);
            when Flex_End =>
               Check_Positions ("flex-end", It, [150.0, 200.0, 250.0]);
            when Center =>
               Check_Positions ("center", It, [75.0, 125.0, 175.0]);
            when Space_Between =>
               Check_Positions ("space-between", It, [0.0, 125.0, 250.0]);
            when Space_Around =>
               Check_Positions ("space-around", It, [25.0, 125.0, 225.0]);
            when Space_Evenly =>
               Check_Positions ("space-evenly", It, [37.5, 125.0, 212.5]);
         end case;

         Check ("sizes preserved: " & Justify_Content'Image (Mode),
                (for all K in It'Range => It (K).Main = 50.0));
         Check ("no overlapping intervals: " & Justify_Content'Image (Mode),
                It (1).Pos_Main + It (1).Main <= It (2).Pos_Main
                and then It (2).Pos_Main + It (2).Main <= It (3).Pos_Main);
      end loop;
   end Test_All_Modes;

   procedure Test_Empty is
      C  : constant Container := (Main => 100.0, others => <>);
      It : Item_Array (1 .. 0);
   begin
      for Mode in Justify_Content loop
         declare
            Config : Container := C;
         begin
            Config.Justify := Mode;
            Resolve (Config, It);
            Check ("empty array: " & Justify_Content'Image (Mode),
                   It'Length = 0);
         end;
      end loop;
   end Test_Empty;

   procedure Test_One_Item is
      C  : Container := (Main => 100.0, others => <>);
      It : Item_Array (1 .. 1) := [others => Fixed_Item (20.0)];
   begin
      for Mode in Justify_Content loop
         C.Justify := Mode;
         Resolve (C, It);
         case Mode is
            when Flex_Start | Space_Between =>
               Check_Positions ("single: " & Justify_Content'Image (Mode),
                                It, [0.0]);
            when Flex_End =>
               Check_Positions ("single: flex-end", It, [80.0]);
            when Center | Space_Around | Space_Evenly =>
               Check_Positions ("single: " & Justify_Content'Image (Mode),
                                It, [40.0]);
         end case;
      end loop;

      --  Odd fixed-point remainder: single-item centering truncates
      --  5 units / 2 to 2 units rather than rounding upward.
      C.Main := Length'(20.0 + 5.0 * Precision);
      for Mode in Justify_Content loop
         if Mode in Center | Space_Around | Space_Evenly then
            C.Justify := Mode;
            Resolve (C, It);
            Check_Positions
               ("single: odd-unit centering " & Justify_Content'Image (Mode),
                It, [Coord'(2.0 * Precision)]);
         end if;
      end loop;
   end Test_One_Item;

   procedure Test_Two_Items is
      C  : constant Container :=
         (Main => 200.0, Justify => Space_Between, others => <>);
      It : Item_Array (1 .. 2) := [others => Fixed_Item (50.0)];
   begin
      Resolve (C, It);
      Check_Positions ("two items: space-between", It, [0.0, 150.0]);
   end Test_Two_Items;

   procedure Test_No_Free_Space is
      C  : Container := (Main => 150.0, others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (50.0)];
   begin
      for Mode in Justify_Content loop
         C.Justify := Mode;
         Resolve (C, It);
         Check_Positions ("zero free: " & Justify_Content'Image (Mode),
                          It, [0.0, 50.0, 100.0]);
      end loop;
   end Test_No_Free_Space;

   procedure Test_Overflow is
      C  : Container := (Main => 100.0, others => <>);
      It : Item_Array (1 .. 2) := [others => Fixed_Item (60.0)];
   begin
      --  Disable shrinking so the occupied width exceeds C.Main.
      for K in It'Range loop
         It (K).Shrink := 0.0;
      end loop;
      for Mode in Justify_Content loop
         C.Justify := Mode;
         Resolve (C, It);
         Check_Positions ("negative free: " & Justify_Content'Image (Mode),
                          It, [0.0, 60.0]);
      end loop;
   end Test_Overflow;

   procedure Test_Margins_And_Gap is
      C  : constant Container :=
         (Main => 250.0, Main_Gap => 10.0,
          Justify => Space_Between, others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (50.0)];
   begin
      It (1).Margin_Main_Start := 5.0;
      It (1).Margin_Main_End   := 7.0;
      It (2).Margin_Main_Start := 3.0;
      It (2).Margin_Main_End   := 4.0;
      It (3).Margin_Main_Start := 2.0;
      It (3).Margin_Main_End   := 9.0;
      --  Occupied = 150 sizes + 30 margins + 20 gaps = 200.
      --  Free = 50, so each of the two extra gaps gets 25.
      Resolve (C, It);
      Check_Positions ("margins and 10px gap", It, [5.0, 100.0, 191.0]);
      Check ("trailing margin ends at container edge",
             It (3).Pos_Main + It (3).Main + It (3).Margin_Main_End = C.Main);
   end Test_Margins_And_Gap;

   procedure Test_Shifted_Indices is
      C  : constant Container :=
         (Main => 90.0, Justify => Space_Between, others => <>);
      It : Item_Array (5 .. 7) := [others => Fixed_Item (10.0)];
   begin
      Resolve (C, It);
      Check_Positions ("array indices 5..7", It, [0.0, 40.0, 80.0]);
   end Test_Shifted_Indices;

   procedure Test_Unit_Remainder is
      C  : Container :=
         (Main => Length'(30.0 + 5.0 * Precision), others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (10.0)];
   begin
      --  Five of the smallest representable fixed-point units remain.
      --  Space-between: two gaps receive 3 then 2 units.
      C.Justify := Space_Between;
      Resolve (C, It);
      Check_Positions
         ("five units: between = 3+2", It,
          [0.0,
           Coord'(10.0 + 3.0 * Precision),
           Coord'(20.0 + 5.0 * Precision)]);

      --  Space-evenly: four gaps receive 2,1,1,1 units.
      C.Justify := Space_Evenly;
      Resolve (C, It);
      Check_Positions
         ("five units: evenly = 2+1+1+1", It,
          [Coord'(2.0 * Precision),
           Coord'(10.0 + 3.0 * Precision),
           Coord'(20.0 + 4.0 * Precision)]);

      --  Space-around: six conceptual half-gaps receive 1,1,1,1,1,0.
      C.Justify := Space_Around;
      Resolve (C, It);
      Check_Positions
         ("five units: around half-gaps", It,
          [Coord'(1.0 * Precision),
           Coord'(10.0 + 3.0 * Precision),
           Coord'(20.0 + 5.0 * Precision)]);

      Check ("remainder never exceeds container",
             It (3).Pos_Main + It (3).Main <= C.Main);
   end Test_Unit_Remainder;

   procedure Test_Pixel_Fractions is
      C  : Container := (Main => 31.0, others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (10.0)];
   begin
      --  One whole pixel of free space is distributed in subpixel units.
      C.Justify := Space_Between;
      Resolve (C, It);
      Check_Positions ("one pixel: between, 1/2px per gap",
                       It, [0.0, 10.5, 21.0]);

      C.Justify := Space_Evenly;
      Resolve (C, It);
      Check_Positions ("one pixel: evenly, 1/4px per gap",
                       It, [0.25, 10.5, 20.75]);

      --  One pixel = 256 units; six half-gaps = 42 each, remainder 4.
      C.Justify := Space_Around;
      Resolve (C, It);
      Check_Positions
         ("one pixel: around, 256 units across six half-gaps", It,
          [Coord'(43.0 * Precision),
           Coord'(10.0 + 129.0 * Precision),
           Coord'(20.0 + 214.0 * Precision)]);
   end Test_Pixel_Fractions;

   procedure Test_Resolved_Flex_Sizes is
      C  : Container :=
         (Main => 90.0, Justify => Space_Evenly, others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (10.0)];
   begin
      --  Grow consumes all free space before justification is applied.
      for K in It'Range loop
         It (K).Grow := 1.0;
      end loop;
      Resolve (C, It);
      Check ("grow consumes free space",
             (for all K in It'Range => It (K).Main = 30.0));
      Check_Positions ("justify follows grown sizes", It, [0.0, 30.0, 60.0]);

      --  Shrink also precedes justification.
      C.Main := 60.0;
      It := [others => Fixed_Item (40.0)];
      Resolve (C, It);
      Check ("shrink consumes overflow",
             (for all K in It'Range => It (K).Main = 20.0));
      Check_Positions ("justify follows shrunk sizes", It, [0.0, 20.0, 40.0]);
   end Test_Resolved_Flex_Sizes;

   procedure Test_Column is
      C  : constant Container :=
         (Main => 90.0, Cross => 100.0,
          Direction => Column, Justify => Space_Between, others => <>);
      It : Item_Array (1 .. 3) := [others => Fixed_Item (10.0)];
   begin
      --  Resolve uses main/cross coordinates; column is a main-axis case.
      Resolve (C, It);
      Check_Positions ("column main-axis justification", It, [0.0, 40.0, 80.0]);
   end Test_Column;

   procedure Test_Max_Nodes is
      C  : constant Container :=
         (Main => 1.0, Justify => Space_Between, others => <>);
      It : Item_Array (1 .. Max_Nodes) := [others => Fixed_Item (0.0)];
      Ordered : Boolean := True;
   begin
      Resolve (C, It);
      for K in It'First + 1 .. It'Last loop
         if It (K - 1).Pos_Main > It (K).Pos_Main then
            Ordered := False;
         end if;
      end loop;
      Check ("max nodes: offsets monotone", Ordered);
      Check ("max nodes: all free space assigned",
             It (It'First).Pos_Main = 0.0
             and then It (It'Last).Pos_Main = 1.0);
   end Test_Max_Nodes;

begin
   Put_Line ("--- justify-content regression suite ---");
   Test_All_Modes;
   Test_Empty;
   Test_One_Item;
   Test_Two_Items;
   Test_No_Free_Space;
   Test_Overflow;
   Test_Margins_And_Gap;
   Test_Shifted_Indices;
   Test_Unit_Remainder;
   Test_Pixel_Fractions;
   Test_Resolved_Flex_Sizes;
   Test_Column;
   Test_Max_Nodes;
end Justify_Regression;
