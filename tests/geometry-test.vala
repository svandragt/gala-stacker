using Gala.Plugins.Stacker;

void test_next_fraction_width_steps_up () {
    double[] fractions = { 1.0 / 3.0, 1.0 / 2.0, 2.0 / 3.0 };

    // At (near) 1/3 of a 900px area, the next step is 1/2.
    assert (Geometry.next_fraction_width (300, 900, fractions) == 450);

    // At 1/2, the next step is 2/3.
    assert (Geometry.next_fraction_width (450, 900, fractions) == 600);

    // At 2/3, it wraps back around to 1/3.
    assert (Geometry.next_fraction_width (600, 900, fractions) == 300);
}

void test_next_fraction_width_picks_closest_when_between_steps () {
    double[] fractions = { 1.0 / 3.0, 1.0 / 2.0, 2.0 / 3.0 };

    // 340px is closer to 1/3 (300px) than 1/2 (450px) of a 900px area,
    // so it should be treated as sitting on the 1/3 step and advance to 1/2.
    assert (Geometry.next_fraction_width (340, 900, fractions) == 450);
}

void test_cap_delta_to_min_width_passes_through_when_room () {
    // Shrinking a 400px neighbor by 100px leaves it at 300px, well above
    // a 50px floor, so the delta is unchanged.
    assert (Geometry.cap_delta_to_min_width (400, 100, 50) == 100);
}

void test_cap_delta_to_min_width_caps_when_it_would_go_below_floor () {
    // Shrinking a 120px neighbor by 100px would take it to 20px, below
    // the 50px floor, so the delta is capped to leave it exactly at 50px.
    assert (Geometry.cap_delta_to_min_width (120, 100, 50) == 70);
}

void test_resize_delta_for_op_maps_right_edges_to_positive_one () {
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_E) == 1);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_NE) == 1);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_SE) == 1);
}

void test_resize_delta_for_op_maps_left_edges_to_negative_one () {
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_W) == -1);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_NW) == -1);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_SW) == -1);
}

void test_resize_delta_for_op_ignores_non_horizontal_ops () {
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_N) == 0);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.RESIZING_S) == 0);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.MOVING) == 0);
    assert (Geometry.resize_delta_for_op (Meta.GrabOp.NONE) == 0);
}

void test_is_resize_op_true_for_every_resize_variant () {
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_N));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_S));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_E));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_W));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_NE));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_NW));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_SE));
    assert (Geometry.is_resize_op (Meta.GrabOp.RESIZING_SW));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_UNKNOWN));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_N));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_S));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_E));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_W));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_NE));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_NW));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_SE));
    assert (Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_RESIZING_SW));
}

void test_is_resize_op_false_for_moving_and_none () {
    assert (!Geometry.is_resize_op (Meta.GrabOp.MOVING));
    assert (!Geometry.is_resize_op (Meta.GrabOp.MOVING_UNCONSTRAINED));
    assert (!Geometry.is_resize_op (Meta.GrabOp.KEYBOARD_MOVING));
    assert (!Geometry.is_resize_op (Meta.GrabOp.NONE));
}

public static int main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/geometry/next_fraction_width/steps_up", test_next_fraction_width_steps_up);
    Test.add_func ("/geometry/next_fraction_width/picks_closest_when_between_steps",
        test_next_fraction_width_picks_closest_when_between_steps);
    Test.add_func ("/geometry/cap_delta_to_min_width/passes_through_when_room",
        test_cap_delta_to_min_width_passes_through_when_room);
    Test.add_func ("/geometry/cap_delta_to_min_width/caps_when_it_would_go_below_floor",
        test_cap_delta_to_min_width_caps_when_it_would_go_below_floor);
    Test.add_func ("/geometry/resize_delta_for_op/maps_right_edges_to_positive_one",
        test_resize_delta_for_op_maps_right_edges_to_positive_one);
    Test.add_func ("/geometry/resize_delta_for_op/maps_left_edges_to_negative_one",
        test_resize_delta_for_op_maps_left_edges_to_negative_one);
    Test.add_func ("/geometry/resize_delta_for_op/ignores_non_horizontal_ops",
        test_resize_delta_for_op_ignores_non_horizontal_ops);
    Test.add_func ("/geometry/is_resize_op/true_for_every_resize_variant",
        test_is_resize_op_true_for_every_resize_variant);
    Test.add_func ("/geometry/is_resize_op/false_for_moving_and_none",
        test_is_resize_op_false_for_moving_and_none);

    return Test.run ();
}
