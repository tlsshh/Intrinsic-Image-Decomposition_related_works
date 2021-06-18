function out=refine(im)
	if(matlabpool('size')==0)
		matlabpool open 3;
	end
	Options.kernelratio=4;
	Options.windowratio=4;
	Options.verbose=true;
	Options.filterstrength=0.02;
	parfor i=1:3
		im(:,:,i)=NLMF_zhengguo(im(:,:,i),Options);
	end
	out=im;
end