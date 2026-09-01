
#%%
import rtcl_d3xx

# %%
dev = rtcl_d3xx.Fifo32(dev_index=0)
core_id = dev.read_axi4l(0x0000_0000)
print(f"core_id: {core_id:#010x}")

