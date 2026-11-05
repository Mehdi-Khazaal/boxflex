--  Unit tests. Plain Ada, no framework: each Check prints PASS/FAIL
--  and the program exits non-zero if anything failed. Add a test for
--  every behaviour you implement; CI runs this on every push.
--
--  Tests marked "pending" document the expected result once
--  Boxflex.Layout_Plain.Compute is implemented. Un-comment them as you go.

with Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Boxflex;          use Boxflex;
with Boxflex.Geometry; use Boxflex.Geometry;
with Boxflex.Style;    use Boxflex.Style;
with Boxflex.Tree;     use Boxflex.Tree;
with Boxflex.Flex;
with Boxflex.Layout_Plain;

procedure Tests is

   Failures : Natural := 0;

   procedure Check (Name : String; Condition : Boolean) is
   begin
      if Condition then
         Put_Line ("PASS  " & Name);
      else
         Put_Line ("FAIL  " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   ---------------------------------------------------------------------
   --  Geometry
   ---------------------------------------------------------------------

   procedure Test_Geometry is
      A : constant Rect := Make (0.0, 0.0, 100.0, 50.0);
      B : constant Rect := Make (10.0, 10.0, 20.0, 20.0);
      C : constant Rect := Make (100.0, 0.0, 10.0, 10.0);
      I : constant Rect := Inset (A, 5.0, 5.0, 5.0, 5.0);
      J : constant Rect := Inset (B, 15.0, 0.0, 15.0, 0.0);
   begin
      Check ("Right",           Right (A) = 100.0);
      Check ("Bottom",          Bottom (A) = 50.0);
      Check ("Contains",        Contains (A, B));
      Check ("not Contains",    not Contains (B, A));
      Check ("Overlaps",        Overlaps (A, B));
      Check ("touching edges do not overlap", not Overlaps (A, C));
      Check ("Inset origin",    I.Origin = (X => 5.0, Y => 5.0));
      Check ("Inset extent",    I.Extent = (Width => 90.0, Height => 40.0));
      Check ("Inset clamps at zero", J.Extent.Width = 0.0);
      Check ("Inset stays inside", Contains (A, I));
      Check ("Translate",
             Translate (B, 5.0, -5.0).Origin = (X => 15.0, Y => 5.0));
      Check ("fixed point resolution",
             Coord'Small = Precision and Coord'Succ (0.0) = Coord (Precision));
   end Test_Geometry;

   ---------------------------------------------------------------------
   --  Tree
   ---------------------------------------------------------------------

   procedure Test_Tree is
      T : Layout_Tree;
      R, A, B, C : Node_Id;
   begin
      Check ("empty tree is well formed", Well_Formed (T));
      Insert (T, No_Node, Default_Style, R);
      Check ("root is node 1", R = 1);
      Insert (T, R, Default_Style, A);
      Insert (T, R, Default_Style, B);
      Insert (T, A, Default_Style, C);
      Check ("count", T.Count = 4);
      Check ("parent links", Parent_Of (T, C) = A and Parent_Of (T, A) = R);
      Check ("first child", First_Child_Of (T, R) = A);
      Check ("sibling", Next_Sibling_Of (T, A) = B);
      Check ("last sibling", Next_Sibling_Of (T, B) = No_Node);
      Check ("child count root", Child_Count (T, R) = 2);
      Check ("child count leaf", Child_Count (T, B) = 0);
      Check ("well formed after inserts", Well_Formed (T));
      Clear (T);
      Check ("clear", Is_Empty (T));
   end Test_Tree;

   ---------------------------------------------------------------------
   --  Flex (the engine)
   ---------------------------------------------------------------------

   procedure Test_Flex is
      use Boxflex.Flex;
      C  : Container := (Main => 200.0, Cross => 100.0, others => <>);
      It : Item_Array (1 .. 2) :=
        [1 => (Basis => 50.0, Basis_Definite => True, Content_Cross => 20.0,
               Margin_Main_Start => 5.0, others => <>),
         2 => (Basis => 300.0, Basis_Definite => True, Min_Main => 0.0,
               Max_Main => 80.0, others => <>)];
      L  : Line_Array (1 .. 2);
      N  : Natural;
   begin
      Check ("hypothetical: basis",  Hypothetical_Main (It (1)) = 50.0);
      Check ("hypothetical: clamped", Hypothetical_Main (It (2)) = 80.0);

      Form_Lines (C, It, L, N);
      Check ("no wrap: one line", N = 1 and then L (1) = (First => 1, Last => 2));

      C.Wrap := Wrap;
      C.Main := 100.0;
      Form_Lines (C, It, L, N);
      Check ("wrap: two lines", N = 2 and then L (2) = (First => 2, Last => 2));

      C.Wrap := No_Wrap;
      C.Main := 200.0;
      Resolve (C, It);
      Check ("resolve: sizes",      It (1).Main = 50.0 and then It (2).Main = 80.0);
      Check ("resolve: margin",     It (1).Pos_Main = 5.0);
      Check ("resolve: packed",     It (2).Pos_Main = 55.0);
      Check ("resolve: in range",   Placed_In_Range (It (1)) and Placed_In_Range (It (2)));

      --  Stretch eligibility tests
      --  Case 1: C.Align = Stretch, I.Self = Auto,
      --  I.Cross_Definite = False, Expected return 120
      C.Cross := 120.0;
      C.Align := Stretch;
      It (1).Content_Cross := 30.0;
      It (1).Self := Auto;
      It (1).Cross_Definite := False;
      Resolve (C, It);
      Check ("stretch: eligible and size 120", It (1).Cross = 120.0);

      --  Case 2: C.Align = Stretch, I.Self = Flex_Start,
      --  I.Cross_Definite = False, Expected return 30
      It (1).Self := Flex_Start;
      Resolve (C, It);
      Check ("stretch: not eligible with size 30", It (1).Cross = 30.0);

      --  Case 3: C.Align = Center, I.Self = Stretch, I.Cross_Definite = False,
      --  Expected return 120
      C.Align := Center;
      It (1).Self := Stretch;
      Resolve (C, It);
      Check ("stretch: eligible and size 120", It (1).Cross = 120.0);

      --  Case 4: C.Align = Stretch, I.Self = Auto, I.Cross_Definite = True,
      -- Expected return 30
      C.Align := Stretch;
      It (1).Self := Auto;
      It (1).Cross_Definite := True;
      Resolve (C, It);
      Check ("stretch: not eligible with size 30", It (1).Cross = 30.0);

      --  Case 5: C.Align = Center, I.Self = Auto, I.Cross_Definite = False,
      --  Expected return 30
      C.Align := Center;
      It (1).Self := Auto;
      It (1).Cross_Definite := False;
      Resolve (C, It);
      Check ("stretch: not eligible with size 30", It (1).Cross = 30.0);

      --  Stretch test cases
      --  Case 1: Line_Cross = 120, Start_Margin = 10, End_Margin = 15,
      --  Min_Cross = 0, Max_Cross = 200, should produce 95
      C := (Main => 200.0, Cross => 120.0, Wrap => No_Wrap, others => <>);
      It (1) := (Margin_Cross_Start => 10.0,
                   Margin_Cross_End => 15.0,
                   Cross_Definite => False,
                   Min_Cross => 0.0,
                   Max_Cross => 200.0,
                   Self => Stretch,
                   others => <>);
      Resolve (C, It);
      Check ("stretch: cross size 95", It (1).Cross = 95.0);

      --  Case 2: Line_Cross = 120, Start_Margin = 10, End_Margin = 15,
      --  Min_Cross = 0, Max_Cross = 80, should produce 80
      It (1).Max_Cross := 80.0;
      Resolve (C, It);
      Check ("stretch: cross size 80", It (1).Cross = 80.0);
      --  Case 3: Min_Cross = 110, Max_Cross = 200, should produce 110
      It (1).Min_Cross := 110.0;
      It (1).Max_Cross := 200.0;
      Resolve (C, It);
      Check ("stretch: cross size 110", It (1).Cross = 110.0);

      --  Case 4: Line_Cross = 50, Start_Margin = 40, End_margin = 30, Min_Cross = 0,
      --  should produce 0
      C.Cross := 50.0;
      It (1).Margin_Cross_Start := 40.0;
      It (1).Margin_Cross_End := 30.0;
      It (1).Min_Cross := 0.0;
      Resolve (C, It);
      Check ("stretch: cross size 0", It (1).Cross = 0.0);

      --  Case 5: Min_Cross = 10
      It (1).Min_Cross := 10.0;
      Resolve (C, It);
      Check ("stretch: cross size 10", It (1).Cross = 10.0);

      --  Case 6: Line_cross = 120, Start_Margin = 0, End_Margin = 0, Min_Cross = 90,
      --  Max_Cross = 60, should produce 90
      C.Cross := 120.0;
      It (1).Margin_Cross_Start := 0.0;
      It (1).Margin_Cross_End := 0.0;
      It (1).Min_Cross := 90.0;
      It (1).Max_Cross := 60.0;
      Resolve (C, It);
      Check ("stretch: cross size 90", It (1).Cross = 90.0);
   end Test_Flex;

   ---------------------------------------------------------------------
   --  Grow and shrink (step 3 of the algorithm)
   ---------------------------------------------------------------------

   procedure Test_Grow_Shrink is
      use Boxflex.Flex;
      C     : constant Container := (Main => 200.0, Cross => 100.0, others => <>);
      C300  : constant Container := (Main => 300.0, Cross => 100.0, others => <>);
      It    : Item_Array (1 .. 2);
      Three : Item_Array (1 .. 3);
   begin
      --  Case 1: 200 px row. A wants 50 + 5 px margin, B wants 100.
      --  Free space = 200 - 155 = 45, split 1 : 1, so 22.5 each.
      It := [1 => (Basis => 50.0, Basis_Definite => True,
                   Margin_Main_Start => 5.0, Grow => 1.0, others => <>),
             2 => (Basis => 100.0, Basis_Definite => True,
                   Grow => 1.0, others => <>)];
      Resolve (C, It);
      Check ("grow: equal split", It (1).Main = 72.5 and then It (2).Main = 122.5);
      Check ("grow: B starts after A", It (2).Pos_Main = 77.5);
      --  Case 2: the grow factors add up to less than 1 (0.25 + 0.5 = 0.75),
      --  so only that part of the free space is handed out:
      --  A gets 200 * 0.25 = 50, B gets 200 * 0.5 = 100, and 50 px stay empty.
      It := [1 => (Basis_Definite => True, Grow => 0.25, others => <>),
             2 => (Basis_Definite => True, Grow => 0.5, others => <>)];
      Resolve (C, It);
      Check ("grow: factors under 1", It (1).Main = 50.0 and then It (2).Main = 100.0);
      --  Case 3: a max stops an item. All three start at 0 and grow 1 in 300 px,
      --  so 100 each, but A has max 50: A freezes at 50, and B and C share
      --  the other 250 (125 each).
      Three := [1 => (Basis_Definite => True, Grow => 1.0, Max_Main => 50.0, others => <>),
                others => (Basis_Definite => True, Grow => 1.0, others => <>)];
      Resolve (C300, Three);
      Check ("grow: max freezes",
             Three (1).Main = 50.0 and then Three (2).Main = 125.0
             and then Three (3).Main = 125.0);

      --  Case 4: a min holds an item up. 100 each would leave A under its
      --  min of 150: A freezes at 150, and B and C share the other 150.
      Three := [1 => (Basis_Definite => True, Grow => 1.0, Min_Main => 150.0, others => <>),
                others => (Basis_Definite => True, Grow => 1.0, others => <>)];
      Resolve (C300, Three);
      Check ("grow: min freezes",
             Three (1).Main = 150.0 and then Three (2).Main = 75.0
             and then Three (3).Main = 75.0);

      --  Case 5: A asks for 100 but its max is 50, so it cannot grow at all
      --  and is frozen at 50 before sharing starts. B gets the other 150.
      It := [1 => (Basis => 100.0, Basis_Definite => True, Grow => 1.0,
                   Max_Main => 50.0, others => <>),
             2 => (Basis_Definite => True, Grow => 1.0, others => <>)];
      Resolve (C, It);
      Check ("grow: max below basis", It (1).Main = 50.0 and then It (2).Main = 150.0);

      --  Case 6: factors under 1 after a freeze. A (grow 0.5, max 20) freezes
      --  at 20. B (grow 0.25) still only gets 0.25 of the first free space:
      --  200 * 0.25 = 50.
      It := [1 => (Basis_Definite => True, Grow => 0.5, Max_Main => 20.0, others => <>),
             2 => (Basis_Definite => True, Grow => 0.25, others => <>)];
      Resolve (C, It);
      Check ("grow: factors under 1 after a freeze",
             It (1).Main = 20.0 and then It (2).Main = 50.0);
   end Test_Grow_Shrink;

   ---------------------------------------------------------------------
   --  Layout (the tree walk)
   ---------------------------------------------------------------------

   procedure Test_Layout is
      T : Layout_Tree;
      R, A, B : Node_Id;
      S : Flex_Style;
   begin
      S := Default_Style;
      S.Direction := Row;
      Insert (T, No_Node, S, R);

      S := Default_Style;
      S.Grow := 1.0;
      Insert (T, R, S, A);
      Insert (T, R, S, B);

      Boxflex.Layout_Plain.Compute (T, (Width => 200.0, Height => 100.0));

      Check ("root fills available",
             Layout_Of (T, R) = Make (0.0, 0.0, 200.0, 100.0));
      Check ("structure untouched", Child_Count (T, R) = 2);
      Check ("children placed", Placed (Layout_Of (T, A)) and Placed (Layout_Of (T, B)));

      --  Two equal growers split the main axis.
      Check ("A is left half",  Layout_Of (T, A) = Make (0.0,   0.0, 100.0, 100.0));
      Check ("B is right half", Layout_Of (T, B) = Make (100.0, 0.0, 100.0, 100.0));
      Check ("siblings do not overlap",
             not Overlaps (Layout_Of (T, A), Layout_Of (T, B)));
      Check ("children inside parent",
             Contains (Layout_Of (T, R), Layout_Of (T, A))
             and Contains (Layout_Of (T, R), Layout_Of (T, B)));
   end Test_Layout;

begin
   Test_Geometry;
   Test_Tree;
   Test_Flex;
   Test_Grow_Shrink;
   Test_Layout;

   New_Line;
   if Failures = 0 then
      Put_Line ("all tests passed");
   else
      Put_Line (Failures'Image & " failure(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
