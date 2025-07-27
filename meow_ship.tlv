\m5_TLV_version 1d: tl-x.org
\m5
   / A competition template for:
   /
   / /----------------------------------------------------------------------------\
   / | The First Annual Makerchip ASIC Design Showdown, Summer 2025, Space Battle |
   / \----------------------------------------------------------------------------/
   /
   / Each player or team modifies this template to provide their own custom spacecraft
   / control circuitry. This template is for teams using Verilog. A TL-Verilog-based
   / template is provided separately. Monitor the Showdown Slack channel for updates.
   / Use the latest template for submission.
   /
   / Just 3 steps:
   /   - Replace all YOUR_GITHUB_ID and YOUR_TEAM_NAME.
   /   - Code your logic in the module below.
   /   - Submit by Sun. July 26, 11 PM IST/1:30 PM EDT.
   /
   / Showdown details: https://www.redwoodeda.com/showdown-info and in the reposotory README.
   
   use(m5-1.0)
   
   var(viz_mode, devel)  /// Enables VIZ for development.
                         /// Use "devel" or "demo". ("demo" will be used in competition.)


   macro(team_Dummy1_module, ['
   module team_Dummy1 (
      // Inputs:
      input logic clk, input logic reset,
      input logic signed [7:0] x [m5_SHIP_RANGE], input logic signed [7:0] y [m5_SHIP_RANGE],
      input logic [7:0] energy [m5_SHIP_RANGE],
      input logic [m5_SHIP_RANGE] destroyed,
      input logic signed [7:0] enemy_x_p [m5_SHIP_RANGE], input logic signed [7:0] enemy_y_p [m5_SHIP_RANGE],
      input logic [m5_SHIP_RANGE] enemy_cloaked,
      input logic [m5_SHIP_RANGE] enemy_destroyed,
      // Outputs:
      output logic signed [3:0] x_a [m5_SHIP_RANGE], output logic signed [3:0] y_a [m5_SHIP_RANGE],
      output logic [m5_SHIP_RANGE] attempt_fire, output logic [m5_SHIP_RANGE] attempt_shield, output logic [m5_SHIP_RANGE] attempt_cloak,
      output logic [1:0] fire_dir [m5_SHIP_RANGE]
   );

   localparam signed [7:0] BORDER = 32;
   localparam signed [7:0] MARGIN = 2;

   localparam FIRE_COST = 30;
   localparam CLOAK_COST = 15;
   localparam SHIELD_COST = 25;
   localparam BULLET_SPEED = 9;
   localparam BULLET_TIME = 6;
   localparam BULLET_RANGE = BULLET_SPEED * BULLET_TIME; // 45 units
   localparam [15:0] FIRE_RANGE_SQ = 2000;
   localparam [15:0] NEAR_DISTANCE_SQ = 1000; // radius = 12 units squared

   logic signed [7:0] enemy_x_prev [2:0];
   logic signed [7:0] enemy_y_prev [2:0];
   logic [1:0] enemy_vx_sign [2:0];
   logic [1:0] enemy_vy_sign [2:0];

   integer j;
   always_ff @(posedge clk) begin
     if (reset) begin
         for (j = 0; j < 3; j++) begin
             enemy_x_prev[j] <= 0;
             enemy_y_prev[j] <= 0;
             enemy_vx_sign[j] <= 2;
             enemy_vy_sign[j] <= 2;
         end
     end else begin
         for (j = 0; j < 3; j++) begin
             logic signed [7:0] vx = enemy_x_p[j] - enemy_x_prev[j];
             logic signed [7:0] vy = enemy_y_p[j] - enemy_y_prev[j];
             // 0: Negative, 1: Positive, 2: No Movement
             enemy_vx_sign[j] <= (vx > 0) ? 1 : (vx < 0) ? 0 : 2;
             enemy_vy_sign[j] <= (vy > 0) ? 1 : (vy < 0) ? 0 : 2;
             enemy_x_prev[j] <= enemy_x_p[j];
             enemy_y_prev[j] <= enemy_y_p[j];
         end
     end
   end

   // --------- BEGIN EXTRA STATE FOR SHIELD LOGIC --------
   logic ship2_dead;
   logic [1:0] alive_count;
   logic [1:0] alive_first, alive_second;
   always_comb begin
     ship2_dead = destroyed[2];
     alive_count = 0;
     alive_first = 0;
     alive_second = 0;
     if (!destroyed[0]) begin alive_first = 0; alive_count++; end
     if (!destroyed[1]) begin
        if (alive_count==0) alive_first = 1;
        else alive_second = 1;
        alive_count++;
     end
     if (!destroyed[2]) begin
        if (alive_count==0) alive_first = 2;
        else if (alive_count==1) alive_second = 2;
        alive_count++;
     end
   end
   // --------- END EXTRA STATE FOR SHIELD LOGIC --------

   genvar i;
   generate
   for (i = 0; i < 3; i++) begin : ship_logic

      wire signed [7:0] dx0_now = enemy_x_p[0] - x[i];
      wire signed [7:0] dy0_now = enemy_y_p[0] - y[i];
      wire signed [7:0] dx1_now = enemy_x_p[1] - x[i];
      wire signed [7:0] dy1_now = enemy_y_p[1] - y[i];
      wire signed [7:0] dx2_now = enemy_x_p[2] - x[i];
      wire signed [7:0] dy2_now = enemy_y_p[2] - y[i];

      wire signed [7:0] dx0_prev = enemy_x_prev[0] - x[i];
      wire signed [7:0] dy0_prev = enemy_y_prev[0] - y[i];
      wire signed [7:0] dx1_prev = enemy_x_prev[1] - x[i];
      wire signed [7:0] dy1_prev = enemy_y_prev[1] - y[i];
      wire signed [7:0] dx2_prev = enemy_x_prev[2] - x[i];
      wire signed [7:0] dy2_prev = enemy_y_prev[2] - y[i];

      wire valid0 = !enemy_destroyed[0] && !enemy_cloaked[0];
      wire valid1 = !enemy_destroyed[1] && !enemy_cloaked[1];
      wire valid2 = !enemy_destroyed[2] && !enemy_cloaked[2];

      function is_approaching;
          input signed [7:0] dx_now, dy_now, dx_prev, dy_prev;
          begin
              is_approaching =
                 ((dx_now*dx_now + dy_now*dy_now) < (dx_prev*dx_prev + dy_prev*dy_prev));
          end
      endfunction

      function is_enemy_approaching_dir;
         input signed [7:0] dx, dy;
         input [1:0] vx_s, vy_s;
         begin
             is_enemy_approaching_dir =
                  ((vx_s == 1 && dx < 0) || (vx_s == 0 && dx > 0) || (vx_s == 2)) ||
                  ((vy_s == 1 && dy < 0) || (vy_s == 0 && dy > 0) || (vy_s == 2)); 
         end
      endfunction

      wire fire_on_0 = valid0 && ((is_approaching(dx0_now, dy0_now, dx0_prev, dy0_prev)) || (is_enemy_approaching_dir(dx0_now, dy0_now, enemy_vx_sign[0], enemy_vy_sign[0])));
      wire fire_on_1 = valid1 && ((is_approaching(dx1_now, dy1_now, dx1_prev, dy1_prev)) || (is_enemy_approaching_dir(dx1_now, dy1_now, enemy_vx_sign[1], enemy_vy_sign[1])));
      wire fire_on_2 = valid2 && ((is_approaching(dx2_now, dy2_now, dx2_prev, dy2_prev)) || (is_enemy_approaching_dir(dx2_now, dy2_now, enemy_vx_sign[2], enemy_vy_sign[2])));

      wire [1:0] target = fire_on_0 ? 2'd0 : fire_on_1 ? 2'd1 : 2'd2;

      // --- Compute dx and dy to target enemy ---
      wire signed [7:0] dx_fire = enemy_x_p[target] - x[i];
      wire signed [7:0] dy_fire = enemy_y_p[target] - y[i];

      // --- Compute previous dx and dy to target enemy ---
      wire signed [7:0] dx_fire_prev = enemy_x_prev[target] - x[i];
      wire signed [7:0] dy_fire_prev = enemy_y_prev[target] - y[i];

      // Absolute values needed for approach-detection
      wire [7:0] abs_dx_fire_now = (dx_fire[7]) ? -dx_fire : dx_fire;
      wire [7:0] abs_dy_fire_now = (dy_fire[7]) ? -dy_fire : dy_fire;
      wire [7:0] abs_dx_fire_prev = (dx_fire_prev[7]) ? -dx_fire_prev : dx_fire_prev;
      wire [7:0] abs_dy_fire_prev = (dy_fire_prev[7]) ? -dy_fire_prev : dy_fire_prev;

      // --- Determine if approaching in X or Y separately ---
      wire approaching_x = (abs_dx_fire_now - abs_dx_fire_prev);
      wire approaching_y = (abs_dy_fire_now - abs_dy_fire_prev);

      // --- Fire direction logic as per your new requested behavior ---
      // If approaching in Y, shoot horizontally (left/right)
      // If approaching in X, shoot vertically (up/down)
      // Priority: If approaching both axes, prefer approaching Y first (can be modified)

      assign fire_dir[i] =
      (approaching_x > approaching_y) ? 
      ((dy_fire >= 0) ? 2'd3 : 2'd1) :
      (
      (approaching_x < approaching_y) ?       // You need to clarify this condition; here replaced by 1'b1 to always pick next branch
      ((dx_fire >= 0) ? 2'd0 : 2'd2) :
      (
      (abs_dx_fire_now >= abs_dy_fire_now) ?
        ((dx_fire >= 0) ? 2'd0 : 2'd2) :
        ((dy_fire >= 0) ? 2'd3 : 2'd1)
      )
      );

      // === Shield/fire decision logic ===
      // Logic: Only i==2 shields by default; others fire.
      // If ship 2 destroyed, one of 0 or 1 shields, based on proximity or alive_first
      
      wire [15:0] d_sq0 = valid0 ? (dx0_prev * dx0_prev + dy0_prev * dy0_prev) : 16'hFFFF;
      wire [15:0] d_sq1 = valid1 ? (dx1_prev * dx1_prev + dy1_prev * dy1_prev) : 16'hFFFF;
      wire [15:0] d_sq2 = valid2 ? (dx2_prev * dx2_prev + dy2_prev * dy2_prev) : 16'hFFFF;

      wire [15:0] min_dist_sq = (d_sq0 <= d_sq1) ? ((d_sq0 <= d_sq2) ? d_sq0 : d_sq2)
                                                     : ((d_sq1 <= d_sq2) ? d_sq1 : d_sq2);

      wire near_enemy = (min_dist_sq <= NEAR_DISTANCE_SQ);

      logic fire_allowed, shield_allowed;
      always_comb begin
        fire_allowed = 0;
        shield_allowed = 0;

        if (!destroyed[2]) begin
          if (i == 2) begin
              shield_allowed = 1;
          end else begin
            if (near_enemy)
              shield_allowed = 1;
            else if (energy[i] >= FIRE_COST)
              fire_allowed = 1;
          end
        end else begin
          // Ship 2 destroyed:
          if ((alive_count >= 2) && (i == 0 || i == 1)) begin
            if (i == alive_first)
              shield_allowed = (energy[i] >= SHIELD_COST) && near_enemy;
            else
              fire_allowed = (energy[i] >= FIRE_COST);
          end else if ((alive_count == 1) && (i != 2 && !destroyed[i])) begin
            if (near_enemy)
              shield_allowed = (energy[i] >= SHIELD_COST);
            else
              fire_allowed = (energy[i] >= FIRE_COST);
          end
        end
      end

      assign attempt_fire[i] = fire_allowed && (fire_on_0 || fire_on_1 || fire_on_2);
      assign attempt_shield[i] = shield_allowed;

      // === Acceleration / Movement logic unchanged ===

      wire [15:0] dist_sq0 = dx0_now * dx0_now + dy0_now * dy0_now;
      wire [15:0] dist_sq1 = dx1_now * dx1_now + dy1_now * dy1_now;
      wire [15:0] dist_sq2 = dx2_now * dx2_now + dy2_now * dy2_now;

      wire [15:0] best_dist_sq =
        (valid0 && (!valid1 || dist_sq0 <= dist_sq1) && (!valid2 || dist_sq0 <= dist_sq2)) ? dist_sq0 :
        (valid1 && (!valid2 || dist_sq1 <= dist_sq2)) ? dist_sq1 :
        (valid2) ? dist_sq2 : 16'hFFFF;

      wire signed [7:0] mv_dx =
        (valid0 && (dist_sq0 == best_dist_sq)) ? dx0_now :
        (valid1 && (dist_sq1 == best_dist_sq)) ? dx1_now :
        (valid2 && (dist_sq2 == best_dist_sq)) ? dx2_now : 8'd0;

      wire signed [7:0] mv_dy =
        (valid0 && (dist_sq0 == best_dist_sq)) ? dy0_now :
        (valid1 && (dist_sq1 == best_dist_sq)) ? dy1_now :
        (valid2 && (dist_sq2 == best_dist_sq)) ? dy2_now : 8'd0;

      // Step size logic: move +/-2 or +/-1 depending on magnitude
      wire signed [2:0] step_x = 
        (mv_dx > 2)  ? 2 : (mv_dx < -2) ? -2 : mv_dx[2:0];
      wire signed [2:0] step_y = 
        (mv_dy > 2)  ? 2 : (mv_dy < -2) ? -2 : mv_dy[2:0];

      assign x_a[i] = (x[i] >= BORDER - MARGIN) ? -2 :
                      (x[i] <= -BORDER + MARGIN) ? 2 :
                      (i==2) ? -step_x :
                      step_x;

      assign y_a[i] = (y[i] >= BORDER - MARGIN) ? -2 :
                      (y[i] <= -BORDER + MARGIN) ? 2 :
                      (i==2) ? -step_y :
                      step_y;

   end
   endgenerate

   endmodule
   '])



\SV
   // Include the showdown framework.
   m4_include_lib(https://raw.githubusercontent.com/rweda/showdown-2025-space-battle/a211a27da91c5dda590feac280f067096c96e721/showdown_lib.tlv)


// [Optional]
// Visualization of your logic for each ship.
\TLV team_Dummy1_viz(/_top, _team_num)
   m5+io_viz(/_top, _team_num)   /// Visualization of your IOs.
   \viz_js
      m5_DefaultTeamVizBoxAndWhere()
      // Add your own visualization of your own logic here, if you like, within the bounds {left: 0..100, top: 0..100}.
      render() {
         // ... draw using fabric.js and signal values. (See VIZ docs under "LEARN" menu.)
         // For example...
         const destroyed = (this.sigVal("team_Dummy1.destroyed").asInt() >> this.getIndex("ship")) & 1;
         return [
            new fabric.Text(destroyed ? "I''m dead! ☹️" : "I''m alive! 😊", {
               left: 10, top: 50, originY: "center", fill: "black", fontSize: 10,
            })
         ];
      },


\TLV team_Dummy1(/_top)
   m5+verilog_wrapper(/_top, Dummy1)



// Compete!
// This defines the competition to simulate (for development).
// When this file is included as a library (for competition), this code is ignored.
\SV
   m5_makerchip_module
\TLV
   // Enlist teams for battle.
   
   // Your team as the first player. Provide:
   //   - your GitHub ID, (as in your \TLV team_* macro, above)
   //   - your team name--anything you like (that isn't crude or disrespectful)
   m5_team(Dummy1, BlueWhale)
   
   // Choose your opponent.
   // Note that inactive teams must be commented with "///", not "//", to prevent M5 macro evaluation.
   ///m5_team(random, Random)
   m5_team(sitting_duck, Sitting Duck)
   ///m5_team(demo1, Test 1)
   
   
   // Instantiate the Showdown environment.
   m5+showdown(/top, /secret)
   
   *passed = /secret$passed || *cyc_cnt > 100;   // Defines max cycles, up to ~600.
   *failed = /secret$failed;
\SV
   endmodule
   // Declare Verilog modules.
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 0)_module, ['m5_call(team_\m5_get_ago(github_id, 0)_module)'])
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 1)_module, ['m5_call(team_\m5_get_ago(github_id, 1)_module)'])
