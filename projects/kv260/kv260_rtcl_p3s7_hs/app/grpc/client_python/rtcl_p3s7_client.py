import grpc
from grpc.tools import protoc

# Ensure generated protobuf modules are available; if not, run protoc to generate them.
try:
    import rtcl_p3s7_control_pb2
    import rtcl_p3s7_control_pb2_grpc
except Exception:
    protoc.main((
        '',
        '-I../server/protos',
        '--python_out=.',
        '--grpc_python_out=.',
        'rtcl_p3s7_control.proto'
    ))
    import rtcl_p3s7_control_pb2
    import rtcl_p3s7_control_pb2_grpc


# Register and system constants
CAMREG_CORE_ID              = 0x0000
CAMREG_CORE_VERSION         = 0x0001
CAMREG_SENSOR_ENABLE        = 0x0004
CAMREG_SENSOR_READY         = 0x0008
CAMREG_RECV_RESET           = 0x0010
CAMREG_ALIGN_RESET          = 0x0020
CAMREG_ALIGN_PATTERN        = 0x0022
CAMREG_ALIGN_STATUS         = 0x0028
CAMREG_DPHY_CORE_RESET      = 0x0080
CAMREG_DPHY_SYS_RESET       = 0x0081
CAMREG_DPHY_INIT_DONE       = 0x0088

SYSREG_ID                   = 0x0000
SYSREG_DPHY_SW_RESET        = 0x0001
SYSREG_CAM_ENABLE           = 0x0002
SYSREG_CSI_DATA_TYPE        = 0x0003
SYSREG_DPHY_INIT_DONE       = 0x0004
SYSREG_FPS_COUNT            = 0x0006
SYSREG_FRAME_COUNT          = 0x0007
SYSREG_IMAGE_WIDTH          = 0x0008
SYSREG_IMAGE_HEIGHT         = 0x0009
SYSREG_BLACK_WIDTH          = 0x000a
SYSREG_BLACK_HEIGHT         = 0x000b

TIMGENREG_CORE_ID           = 0x0000
TIMGENREG_CORE_VERSION      = 0x0001
TIMGENREG_CTL_CONTROL       = 0x0004
TIMGENREG_CTL_STATUS        = 0x0005
TIMGENREG_CTL_TIMER         = 0x0008
TIMGENREG_PARAM_PERIOD      = 0x0010
TIMGENREG_PARAM_TRIG0_START = 0x0020
TIMGENREG_PARAM_TRIG0_END   = 0x0021
TIMGENREG_PARAM_TRIG0_POL   = 0x0022


class RtclP3s7Client:
    """gRPC client wrapper for rtcl_p3s7_control service.

    Provides the register and image helper methods previously defined
    as module-level functions in `rtcl_p3s7_control.py`.
    """

    def __init__(self, address='192.168.16.1:50051'):
        self.channel = grpc.insecure_channel(address)
        self.stub = rtcl_p3s7_control_pb2_grpc.RtclP3s7ControlStub(self.channel)

    def get_version(self):
        res = self.stub.GetVersion(rtcl_p3s7_control_pb2.Empty())
        return res.version

    # Camera control methods
    def camera_open(self):
        res = self.stub.CameraOpen(rtcl_p3s7_control_pb2.Empty())
        return res.result

    def camera_close(self):
        res = self.stub.CameraClose(rtcl_p3s7_control_pb2.Empty())
        return res.result

    def camera_is_opened(self):
        res = self.stub.CameraIsOpened(rtcl_p3s7_control_pb2.Empty())
        return res.result

    def camera_get_module_id(self):
        res = self.stub.CameraGetModuleId(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_get_module_version(self):
        res = self.stub.CameraGetModuleVersion(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_get_sensor_id(self):
        res = self.stub.CameraGetSensorId(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_set_slave_mode(self, enable):
        res = self.stub.CameraSetSlaveMode(rtcl_p3s7_control_pb2.BoolRequest(value=enable))
        return res.result

    def camera_set_trigger_mode(self, enable):
        res = self.stub.CameraSetTriggerMode(rtcl_p3s7_control_pb2.BoolRequest(value=enable))
        return res.result

    def camera_set_image_size(self, width, height):
        res = self.stub.CameraSetImageSize(rtcl_p3s7_control_pb2.ImageSizeRequest(width=width, height=height))
        return res.result

    def camera_get_image_width(self):
        res = self.stub.CameraGetImageWidth(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_get_image_height(self):
        res = self.stub.CameraGetImageHeight(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_set_gain(self, db):
        res = self.stub.CameraSetGain(rtcl_p3s7_control_pb2.F32Request(value=db))
        return res.result

    def camera_get_gain(self):
        res = self.stub.CameraGetGain(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_set_exposure(self, us):
        res = self.stub.CameraSetExposure(rtcl_p3s7_control_pb2.F32Request(value=us))
        return res.result

    def camera_get_exposure(self):
        res = self.stub.CameraGetExposure(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_measure_fps(self):
        res = self.stub.CameraMeasureFps(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    def camera_measure_frame_period(self):
        res = self.stub.CameraMeasureFramePeriod(rtcl_p3s7_control_pb2.Empty())
        return res.value if res.result else None

    # Image capture methods
    def record_image(self, width, height, frames):
        res = self.stub.RecordImage(rtcl_p3s7_control_pb2.RecordImageRequest(width=width, height=height, frames=frames))
        return res.value if res.result else None

    def read_image(self, index):
        res = self.stub.ReadImage(rtcl_p3s7_control_pb2.ReadImageRequest(index=index))
        return res.image if res.result else None

    def record_black(self, width, height, frames):
        res = self.stub.RecordBlack(rtcl_p3s7_control_pb2.RecordImageRequest(width=width, height=height, frames=frames))
        return res.value if res.result else None

    def read_black(self, index):
        res = self.stub.ReadBlack(rtcl_p3s7_control_pb2.ReadImageRequest(index=index))
        return res.image if res.result else None

    # Timing Generator methods
    def set_timing_generator(self, period_us, exposure_us):
        res = self.stub.SetTimingGenerator(rtcl_p3s7_control_pb2.SetTimingGeneratorRequest(period_us=period_us, exposure_us=exposure_us))
        return res.result

    # Low-level register access methods
    def write_sys_reg(self, addr, data):
        res = self.stub.WriteSysReg(rtcl_p3s7_control_pb2.WriteRegRequest(addr=addr, data=data))
        return res.result

    def read_sys_reg(self, addr):
        res = self.stub.ReadSysReg(rtcl_p3s7_control_pb2.ReadRegRequest(addr=addr))
        return res.data if res.result else None

    def read_sys_reg(self, addr):
        res = self.stub.ReadSysReg(rtcl_p3s7_control_pb2.ReadRegRequest(addr=addr))
        return res.data if res.result else None

    def write_cam_reg(self, addr, data):
        res = self.stub.WriteCamReg(rtcl_p3s7_control_pb2.WriteRegRequest(addr=addr, data=data))
        return res.result

    def read_cam_reg(self, addr):
        res = self.stub.ReadCamReg(rtcl_p3s7_control_pb2.ReadRegRequest(addr=addr))
        return res.data if res.result else None

    def write_sensor_reg(self, addr, data):
        res = self.stub.WriteSensorReg(rtcl_p3s7_control_pb2.WriteRegRequest(addr=addr, data=data))
        return res.result

    def read_sensor_reg(self, addr):
        res = self.stub.ReadSensorReg(rtcl_p3s7_control_pb2.ReadRegRequest(addr=addr))
        return res.data if res.result else None
