#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <chromaprint.h>
#include <limits>
using namespace godot;
class SynkChromaprint : public RefCounted {
 GDCLASS(SynkChromaprint, RefCounted)
protected:
 static void _bind_methods() { ClassDB::bind_method(D_METHOD("fingerprint", "pcm", "sample_rate"), &SynkChromaprint::fingerprint); }
public:
 String fingerprint(const PackedByteArray &pcm, int sample_rate) {
  if (sample_rate < 8000 || sample_rate > 192000 || pcm.size() < 2 || pcm.size()%2 || pcm.size()/2 > std::numeric_limits<int>::max()) return String();
  ChromaprintContext *ctx=chromaprint_new(CHROMAPRINT_ALGORITHM_DEFAULT);
  if (!ctx) return String();
  char *encoded=nullptr; String result;
  if (chromaprint_start(ctx,sample_rate,1) && chromaprint_feed(ctx,reinterpret_cast<const int16_t*>(pcm.ptr()),static_cast<int>(pcm.size()/2)) && chromaprint_finish(ctx) && chromaprint_get_fingerprint(ctx,&encoded)) result=String::utf8(encoded);
  if (encoded) chromaprint_dealloc(encoded);
  chromaprint_free(ctx); return result;
 }
};
void initialize(ModuleInitializationLevel level) { if (level==MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(SynkChromaprint); }
void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT synk_chromaprint_init(GDExtensionInterfaceGetProcAddress proc, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
 GDExtensionBinding::InitObject init(proc,library,initialization);init.register_initializer(initialize);init.register_terminator(terminate);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
