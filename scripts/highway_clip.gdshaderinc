// Clip against the rails as seen by the camera, including raised note faces.
// Projecting back onto the highway plane keeps the silhouette inside the rails
// at every camera angle without changing lane centers or touch coordinates.
uniform float rail_half_width=1000.0;
varying vec3 rail_position;
bool outside_rails(vec3 eye){
    float distance_to_plane=(eye.y-0.035)/max(0.001,eye.y-rail_position.y);
    float ground_x=eye.x+(rail_position.x-eye.x)*distance_to_plane;
    return abs(ground_x)>rail_half_width;
}
