/* Compression-based fluid dynamic simulator.
 * uses map_width, map_height, mass, new_mass, blocks, MaxMass, MaxCompression
 *
 * Blocks can contain more than MaxMass water.
 */
void simulate_compression(){
  float Flow = 0;
  float remaining_mass;
  
  //Calculate and apply flow for each block
  for (int x = 1; x <= map_width; x++){
     for(int y = 1; y <= map_height; y++){
       //Skip inert ground blocks
       if ( blocks[x][y] == GROUND) continue;
       
       //Custom push-only flow
       Flow = 0;
       remaining_mass = mass[x][y];
       if ( remaining_mass <= 0 ) continue;
       
       //The block below this one
       if ( (blocks[x][y-1] != GROUND) ){
         Flow = get_stable_state_b( remaining_mass + mass[x][y-1] ) - mass[x][y-1];
         if ( Flow > MinFlow ){
           Flow *= 0.5; //leads to smoother flow
         }
         Flow = constrain( Flow, 0, min(MaxSpeed, remaining_mass) );
         
         new_mass[x][y] -= Flow;
         new_mass[x][y-1] += Flow;   
         remaining_mass -= Flow;
       }
       
       if ( remaining_mass <= 0 ) continue;
       
       //Left
       if ( blocks[x-1][y] != GROUND ){
         //Equalize the amount of water in this block and it's neighbour
         Flow = (mass[x][y] - mass[x-1][y])/4;
         if ( Flow > MinFlow ){ Flow *= 0.5; }
         Flow = constrain(Flow, 0, remaining_mass);
          
         new_mass[x][y] -= Flow;
         new_mass[x-1][y] += Flow;
         remaining_mass -= Flow;
       }
       
       if ( remaining_mass <= 0 ) continue;

       //Right
       if ( blocks[x+1][y] != GROUND ){
         //Equalize the amount of water in this block and it's neighbour
         Flow = (mass[x][y] - mass[x+1][y])/4;
         if ( Flow > MinFlow ){ Flow *= 0.5; }
         Flow = constrain(Flow, 0, remaining_mass);
          
         new_mass[x][y] -= Flow;
         new_mass[x+1][y] += Flow;
         remaining_mass -= Flow;
       }
       
       if ( remaining_mass <= 0 ) continue;
       
       //Up. Only compressed water flows upwards.
       if ( blocks[x][y+1] != GROUND ){
         Flow = remaining_mass - get_stable_state_b( remaining_mass + mass[x][y+1] );
         if ( Flow > MinFlow ){ Flow *= 0.5; }
         Flow = constrain( Flow, 0, min(MaxSpeed, remaining_mass) );
         
         new_mass[x][y] -= Flow;
         new_mass[x][y+1] += Flow;   
         remaining_mass -= Flow;
       }

       
     }
  }
  
  //Copy the new mass values to the mass array
  for (int x = 0; x < map_width + 2; x++){
    for (int y = 0; y < map_height + 2; y++){
      mass[x][y] = new_mass[x][y];
    }
  }
  
  for (int x = 1; x <= map_width; x++){
     for(int y = 1; y <= map_height; y++){
       //Skip ground blocks
       if(blocks[x][y] == GROUND) continue;
       //Flag/unflag water blocks
       if (mass[x][y] > MinMass){
         blocks[x][y] = WATER;
       } else {
         blocks[x][y] = AIR;
       }
     }
  }
  
  //Remove any water that has left the map
  for (int x =0; x < map_width+2; x++){
    mass[x][0] = 0;
    mass[x][map_height+1] = 0;
  }
  for (int y = 1; y < map_height+1; y++){
    mass[0][y] = 0;
    mass[map_width+1][y] = 0;
  }

}
 
//Take an amount of water and calculate how it should be split among two 
//vertically adjacent cells. Returns the amount of water that should be in 
//the bottom cell.
float get_stable_state_b ( float total_mass ){
  if ( total_mass <= 1 ){
    return 1;
  } else if ( total_mass < 2*MaxMass + MaxCompress ){
    return (MaxMass*MaxMass + total_mass*MaxCompress)/(MaxMass + MaxCompress);
  } else {
    return (total_mass + MaxCompress)/2;
  }
}
  
/*
Explanation of get_stable_state_b (well, kind-of) : 

if x <= 1, all water goes to the lower cell
	* a = 0
	* b = 1
	
if x > 1 & x < 2*MaxMass + MaxCompress, the lower cell should have MaxMass + (upper_cell/MaxMass) * MaxCompress
	b = MaxMass + (a/MaxMass)*MaxCompress
	a = x - b
	
	->
	
	b = MaxMass + ((x - b)/MaxMass)*MaxCompress ->
        b = MaxMass + (x*MaxCompress - b*MaxCompress)/MaxMass
        b*MaxMass = MaxMass^2 + (x*MaxCompress - b*MaxCompress)
        b*(MaxMass + MaxCompress) = MaxMass*MaxMass + x*MaxCompress
        
        * b = (MaxMass*MaxMass + x*MaxCompress)/(MaxMass + MaxCompress)
	* a = x - b;
	
if x >= 2 * MaxMass + MaxCompress, the lower cell should have upper+MaxCompress
	  
	b = a + MaxCompress
	a = x - b 
	
	->
	
	b = x - b + MaxCompress ->
	2b = x + MaxCompress ->
	
	* b = (x + MaxCompress)/2
	* a = x - b
  */