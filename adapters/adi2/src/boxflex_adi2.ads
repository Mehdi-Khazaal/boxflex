--  adi2 adapter: adi2's flex seam, answered by boxflex.
--
--  adi2 (src/adi-layout_util.ads) resolves one container's children with
--
--     procedure Compute_Flex_Layout
--       (Context  : Flex_Layout_Context;
--        Children : in out Flex_Child_Info_Array);
--
--  Same shape as Boxflex.Flex.Resolve, in Float. This package has the
--  same signature, so adi2's Perform_Flex_Layout can call it instead
--  (one indirection, or a build scenario, in adi2).
--
--  Milestone 3 stretch goal: adi2 built against this, its test suite
--  green. Fixed point vs Float will differ below 1/256 px; a tolerance
--  in adi2's layout tests is fair, anything above is a boxflex bug.
--
--  NOT BUILT BY CI. It needs adi2 (see alire.toml, pin the commit).

with Adi.Layout_Util;

package Boxflex_Adi2 is

   procedure Compute_Flex_Layout
     (Context  : Adi.Layout_Util.Flex_Layout_Context;
      Children : in out Adi.Layout_Util.Flex_Child_Info_Array);

end Boxflex_Adi2;
