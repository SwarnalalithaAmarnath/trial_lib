\m5_TLV_version 1d: tl-x.org
\m5
   / A competition template for:
   / my logic
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


   macro(team_swarna_module, ['
      module team_swarna(
         // Inputs:
         input logic clk, input logic reset,
         input logic signed [7:0] x [m5_SHIP_RANGE], input logic signed [7:0] y [m5_SHIP_RANGE],   // Positions of your ships, as affected by last cycle's acceleration.
         input logic [7:0] energy [m5_SHIP_RANGE],   // The energy supply of each ship, as affected by last cycle's actions.
         input logic [m5_SHIP_RANGE] destroyed,   // Asserted if and when the ships are destroyed.
         input logic signed [7:0] enemy_x_p [m5_SHIP_RANGE], input logic signed [7:0] enemy_y_p [m5_SHIP_RANGE],   // Positions of enemy ships as affected by their acceleration last cycle.
         input logic [m5_SHIP_RANGE] enemy_cloaked,   // Whether the enemy ships are cloaked, in which case their enemy_x_p and enemy_y_p will not update.
         input logic [m5_SHIP_RANGE] enemy_destroyed, // Whether the enemy ships have been destroyed.
         // Outputs:
         output logic signed [3:0] x_a [m5_SHIP_RANGE], output logic signed [3:0] y_a [m5_SHIP_RANGE],  // Attempted acceleration for each of your ships; capped by max_acceleration (see showdown_lib.tlv).
         output logic [m5_SHIP_RANGE] attempt_fire, output logic [m5_SHIP_RANGE] attempt_shield, output logic [m5_SHIP_RANGE] attempt_cloak,  // Attempted actions for each of your ships.
         output logic [1:0] fire_dir [m5_SHIP_RANGE]   // Direction to fire (if firing). (For the first player: 0 = right, 1 = down, 2 = left, 3 = up)
      );

     localparam signed [7:0] BORDER = 32;
localparam signed [7:0] MARGIN = 2;

localparam FIRE_COST = 30;
localparam CLOAK_COST = 15;
localparam SHIELD_COST = 25;
localparam BULLET_SPEED = 9;
localparam BULLET_TIME = 6;
localparam BULLET_RANGE = BULLET_SPEED * BULLET_TIME; // 45 units
localparam [15:0] FIRE_RANGE_SQ = 2500;

logic signed [7:0] enemy_x_prev [2:0];
logic signed [7:0] enemy_y_prev [2:0];
logic [1:0] enemy_vx_sign [2:0];
logic [1:0] enemy_vy_sign [2:0];

function is_target_in_fire_dir;
  input signed [7:0] dx, dy;
  input [1:0] dir;
  begin
      case (dir)
          2'd0: is_target_in_fire_dir = (dx > 0) && (dy > -dx) && (dy < dx);   // Right
          2'd1: is_target_in_fire_dir = (dy > 0) && (dx > -dy) && (dx < dy);   // Down
          2'd2: is_target_in_fire_dir = (dx < 0) && (dy > dx) && (dy < -dx);   // Left
          2'd3: is_target_in_fire_dir = (dy < 0) && (dx > dy) && (dx < -dy);   // Up
          default: is_target_in_fire_dir = 1'b0;
      endcase
  end
endfunction

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
          enemy_vx_sign[j] <= (vx > 0) ? 1 : (vx < 0) ? 0 : 2;
          enemy_vy_sign[j] <= (vy > 0) ? 1 : (vy < 0) ? 0 : 2;
          enemy_x_prev[j] <= enemy_x_p[j];
          enemy_y_prev[j] <= enemy_y_p[j];
      end
  end
end

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

  wire signed [7:0] vx0 = enemy_x_p[0] - enemy_x_prev[0];
  wire signed [7:0] vy0 = enemy_y_p[0] - enemy_y_prev[0];
  wire signed [7:0] vx1 = enemy_x_p[1] - enemy_x_prev[1];
  wire signed [7:0] vy1 = enemy_y_p[1] - enemy_y_prev[1];
  wire signed [7:0] vx2 = enemy_x_p[2] - enemy_x_prev[2];
  wire signed [7:0] vy2 = enemy_y_p[2] - enemy_y_prev[2];

  wire [7:0] abs_dx0 = dx0_now[7] ? -dx0_now : dx0_now;
  wire [7:0] abs_dy0 = dy0_now[7] ? -dy0_now : dy0_now;
  wire [7:0] abs_dx1 = dx1_now[7] ? -dx1_now : dx1_now;
  wire [7:0] abs_dy1 = dy1_now[7] ? -dy1_now : dy1_now;
  wire [7:0] abs_dx2 = dx2_now[7] ? -dx2_now : dx2_now;
  wire [7:0] abs_dy2 = dy2_now[7] ? -dy2_now : dy2_now;

  wire [8:0] sum0 = abs_dx0 + abs_dy0;
  wire [8:0] sum1 = abs_dx1 + abs_dy1;
  wire [8:0] sum2 = abs_dx2 + abs_dy2;

 // Unsigned squared distance
  wire [15:0] dist_sq0 = dx0_now * dx0_now + dy0_now * dy0_now;
  wire [15:0] dist_sq1 = dx1_now * dx1_now + dy1_now * dy1_now;
  wire [15:0] dist_sq2 = dx2_now * dx2_now + dy2_now * dy2_now;


  function is_approaching;
      input signed [7:0] dx_now, dy_now, dx_prev, dy_prev;
      begin
          is_approaching =
             ((dx_now*dx_now + dy_now*dy_now) < (dx_prev*dx_prev + dy_prev*dy_prev));
      end
  endfunction

  wire valid0 = !enemy_destroyed[0] && !enemy_cloaked[0];
  wire valid1 = !enemy_destroyed[1] && !enemy_cloaked[1];
  wire valid2 = !enemy_destroyed[2] && !enemy_cloaked[2];

  wire fire_on_0 = valid0 && ((is_approaching(dx0_now, dy0_now, dx0_prev, dy0_prev))  || (is_enemy_approaching_dir(dx0_now, dy0_now, enemy_vx_sign[0], enemy_vy_sign[0]))) ;
  wire fire_on_1 = valid1 && ((is_approaching(dx1_now, dy1_now, dx1_prev, dy1_prev))  || (is_enemy_approaching_dir(dx1_now, dy1_now, enemy_vx_sign[1], enemy_vy_sign[1]))) ;
  wire fire_on_2 = valid2 && ((is_approaching(dx2_now, dy2_now, dx2_prev, dy2_prev))  || (is_enemy_approaching_dir(dx2_now, dy2_now, enemy_vx_sign[2], enemy_vy_sign[2]))) ;


  wire [1:0] target = fire_on_0 ? 2'd0 : fire_on_1 ? 2'd1 : 2'd2;
  wire signed [7:0] dx_fire = enemy_x_p[target] - x[i];
  wire signed [7:0] dy_fire = enemy_y_p[target] - y[i];

  assign fire_dir[i] = ( (dx_fire > dy_fire) && (dx_fire > -dy_fire) ) ? 2'd0 :
                       ( (dx_fire < dy_fire) && (dx_fire > -dy_fire) ) ? 2'd3 :
                       ( (dx_fire < dy_fire) && (dx_fire < -dy_fire) ) ? 2'd2 :
                                                                        2'd1 ;

  function is_enemy_approaching_dir;
      input signed [7:0] dx, dy;
      input [1:0] vx_s, vy_s;
      begin
          is_enemy_approaching_dir =
              ((vx_s == 1 && dx < 0) || (vx_s == 0 && dx > 0) || (vx_s == 2)) ||
              ((vy_s == 1 && dy < 0) || (vy_s == 0 && dy > 0) || (vy_s == 2));
      end
  endfunction

  wire enemy_close0 = valid0 && (sum0 <= (BULLET_RANGE + 10)) && is_enemy_approaching_dir(dx0_now, dy0_now, enemy_vx_sign[0], enemy_vy_sign[0]) ;
  wire enemy_close1 = valid1 && (sum1 <= (BULLET_RANGE + 10)) && is_enemy_approaching_dir(dx1_now, dy1_now, enemy_vx_sign[1], enemy_vy_sign[1]) ;
  wire enemy_close2 = valid2 && (sum2 <= (BULLET_RANGE + 10)) && is_enemy_approaching_dir(dx2_now, dy2_now, enemy_vx_sign[2], enemy_vy_sign[2]) ;

  //assign attempt_cloak[i] = (energy[i] >= CLOAK_COST) && (enemy_close0 || enemy_close1 || enemy_close2);

  wire very_close0 = valid0 && (sum0 <= 12);
  wire very_close1 = valid1 && (sum1 <= 12);
  wire very_close2 = valid2 && (sum2 <= 12);

  assign attempt_fire[i] = 
    (energy[i] >= FIRE_COST) &&
    ((dist_sq0 <= FIRE_RANGE_SQ) || (dist_sq1 <= FIRE_RANGE_SQ) || (dist_sq2 <= FIRE_RANGE_SQ) || 
    (fire_on_0 || fire_on_1 || fire_on_2)) &&
    is_target_in_fire_dir(dx_fire, dy_fire, fire_dir[i]) &&
    !(very_close0 || very_close1 || very_close2);

  //assign attempt_fire[i] = ((energy[i] >= FIRE_COST) && (fire_on_0 || fire_on_1 || fire_on_2));
  //assign attempt_shield[i] =
  //((energy[i] >= SHIELD_COST) && (enemy_close0 || enemy_close1 || enemy_close2)) ||
    //((energy[i] >= SHIELD_COST) && (very_close0 || very_close1 || very_close2));
  //assign attempt_shield[i] = ((is_approaching(dx0_now, dy0_now, dx0_prev, dy0_prev) || is_approaching(dx1_now, dy1_now, dx1_prev, dy1_prev) || is_approaching(dx2_now, dy2_now, dx2_prev, dy2_prev) || (dist_sq0 <= FIRE_RANGE_SQ) || (dist_sq1 <= FIRE_RANGE_SQ) || (dist_sq2 <= FIRE_RANGE_SQ) && energy[i] >= SHIELD_COST));
  assign attempt_shield[i] = 
    (energy[i] >= SHIELD_COST) &&
    (enemy_close0 || enemy_close1 || enemy_close2 || 
    (dist_sq0 <= FIRE_RANGE_SQ) || (dist_sq1 <= FIRE_RANGE_SQ) || (dist_sq2 <= FIRE_RANGE_SQ));

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

          // Border logic: clamp as before
          assign x_a[i] = (x[i] >= BORDER - MARGIN) ? -2 :
                          (x[i] <= -BORDER + MARGIN) ? 2 :
                          (i==1) ? -step_x :
                          step_x;

          assign y_a[i] = (y[i] >= BORDER - MARGIN) ? -2 :
                          (y[i] <= -BORDER + MARGIN) ? 2 :
                          (i==1) ? -step_y :
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
\TLV team_swarna_viz(/_top, _team_num)
   m5+io_viz(/_top, _team_num)   /// Visualization of your IOs.
   \viz_js
      m5_DefaultTeamVizBoxAndWhere()
      // Add your own visualization of your own logic here, if you like, within the bounds {left: 0..100, top: 0..100}.
      render() {
         // ... draw using fabric.js and signal values. (See VIZ docs under "LEARN" menu.)
         // For example...
         const destroyed = (this.sigVal("team_swarna.destroyed").asInt() >> this.getIndex("ship")) & 1;
         return [
            new fabric.Text(destroyed ? "I''m dead! ☹️" : "I''m alive! 😊", {
               left: 10, top: 50, originY: "center", fill: "black", fontSize: 10,
            })
         ];
      },


\TLV team_swarna(/_top)
   m5+verilog_wrapper(/_top, swarna)



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
   m5_team(swarna, swarna)
   
   // Choose your opponent.
   // Note that inactive teams must be commented with "///", not "//", to prevent M5 macro evaluation.
   ///m5_team(random, Random)
   ///m5_team(sitting_duck, Sitting Duck)
   m5_team(demo2, Test 1)
   
   
   // Instantiate the Showdown environment.
   m5+showdown(/top, /secret)
   
   *passed = /secret$passed || *cyc_cnt > 600;   // Defines max cycles, up to ~600.
   *failed = /secret$failed;
\SV
   endmodule
   // Declare Verilog modules.
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 0)_module, ['m5_call(team_\m5_get_ago(github_id, 0)_module)'])
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 1)_module, ['m5_call(team_\m5_get_ago(github_id, 1)_module)'])
