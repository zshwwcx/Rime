
## Update和FixedUpdate

update渲染帧，每两帧之间的执行时间不能保证完全一致。fixedupdate物理帧，保证两帧之间的执行间隔完全一致。

实验证明，update和fixedupdate都是在同一个线程里面执行的(其实整个unity的脚本都是在同一个线程中运行的)，所以如果update或者fixedupdate卡了，都会互相影响对方的执行。

