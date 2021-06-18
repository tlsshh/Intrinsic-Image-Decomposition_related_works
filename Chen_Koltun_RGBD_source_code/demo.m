run('C:\Users\cqf\Google Drive\source_codes/vlfeat-0.9.16/toolbox/vl_setup.m');%Vl_feat library for k-nearest neighbor queries
folder='data\';%data folder
ratio=1;%resize the image to its size times ratio
outputDir='output\';%output folder
index=[1 1964];
for id=index
	%read data
	[image depth mask chroma normals luma]=readData(folder,ratio,id);
	luma=min(max(luma(find(mask))*0.9999+0.0001,0),1);%to avoid log 0
	points=getVectors(size(depth,1),size(depth,2),57);%horizontal field of view 
	points=points.*depth(:,:,[1 1 1]);
    points_whitened=reshape(whiten(reshape(points,[],3)),size(image));%whiten the 3D points
	n=numel(find(mask));%number of pixels
	num_variables=8*n;
	offset=struct('albedo',0,'directIrradiance',3*n,'indirectIrradiance',4*n,'illuminationColor',5*n);%all the variables are aligned in a vector. offset.xxx identifies the index of the first element of xxx
	log_image=max(extract(toLog(image),mask),-6);%max(...,-6) to avoid too small color intensity in log domain.
	normals=reshape(normals,[],3);

	%Data Term
	C1=sparse(n*3,num_variables);
	for i=1:3
		C1((i-1)*n+(1:n),:)=sparse(1:n,offset.illuminationColor+(i-1)*n+(1:n),ones(1,n),n,num_variables)+sparse(1:n,offset.albedo+(i-1)*n+(1:n),ones(1,n),n,num_variables)+sparse(1:n,offset.directIrradiance+(1:n),ones(1,n),n,num_variables)+sparse(1:n,offset.indirectIrradiance+(1:n),ones(1,n),n,num_variables);
	end
	C1=sparse(1:n*3,1:n*3,([luma;luma;luma]+0.1),n*3,n*3)*C1;
	d1=reshape(log_image,[],1);
	d1=d1.*([luma;luma;luma]+0.1);%||C1*x-d1||^2
	
	%albedo regularization
	num_nn_albedo=10;
	ind=randi(n,num_nn_albedo,n);
	edge=[reshape(repmat(1:n,[num_nn_albedo 1]),[],1) reshape(ind,[],1)];%a list of edges N_A
	edge=edge(find(edge(:,1)~=edge(:,2)),:);
	edge=unique([min(edge(:,1),edge(:,2)) max(edge(:,1),edge(:,2))],'rows');
	chroma_vector=reshape(chroma,[],3);
	diff=sum(abs(chroma_vector(edge(:,1),:)-chroma_vector(edge(:,2),:)),2);
	weight_albedo_reg=(1-diff/max(diff)).*sqrt(luma(edge(:,1)).*luma(edge(:,2)));%compute the weight of edges
	weight_albedo_reg=repmat(weight_albedo_reg,[1 3]);
	edge=[edge;edge+n;edge+n*2];%three channels for RGB
	num_albedo_reg=size(edge,1);
	C2=sparse(1:num_albedo_reg,offset.albedo+edge(:,1),weight_albedo_reg,num_albedo_reg,num_variables)-sparse(1:num_albedo_reg,offset.albedo+edge(:,2),weight_albedo_reg,num_albedo_reg,num_variables);
	d2=zeros(num_albedo_reg,1);%||C2*x-d2||^2
	
	%directIrradiance regularization
	feature_directIrradiance=[reshape(points_whitened,[],3) normals]';%feature vector (x,y,z,n_x,n_y,n_z)
	num_nn_directIrradiance=10*round(ratio*2);
	ind=double(vl_kdtreequery(vl_kdtreebuild(feature_directIrradiance),feature_directIrradiance,feature_directIrradiance,'numneighbors',num_nn_directIrradiance));
	edge=[reshape(repmat(1:n,[num_nn_directIrradiance 1]),[],1) reshape(ind,[],1)];%a list of edges N_D
	num_directIrradiance_reg=size(edge,1);
	weight_directIrradiance_reg=ones(1,num_directIrradiance_reg);
	C3=sparse(1:num_directIrradiance_reg,offset.directIrradiance+edge(:,1),weight_directIrradiance_reg,num_directIrradiance_reg,num_variables)-sparse(1:num_directIrradiance_reg,offset.directIrradiance+edge(:,2),weight_directIrradiance_reg,num_directIrradiance_reg,num_variables);
	d3=zeros(num_directIrradiance_reg,1);%||C3*x-d3||^2
	
	
	%indirect Irradiance regularization
	%indirectIrradiance map should be spatially coherent
	feature_indirectIrradiance=[reshape(points,[],3)]';
	num_nn_indirectIrradiance=10*round(ratio*2);
	ind_indirectIrradiance=double(vl_kdtreequery(vl_kdtreebuild(feature_indirectIrradiance),feature_indirectIrradiance,feature_indirectIrradiance,'numneighbors',num_nn_indirectIrradiance));
	edge=[reshape(repmat(1:n,[num_nn_indirectIrradiance 1]),[],1) reshape(ind_indirectIrradiance,[],1)];%a list of edges N_N
	num_indirectIrradiance_reg=size(edge,1);
	weight_indirectIrradiance_reg=ones(1,num_indirectIrradiance_reg);
	C4=sparse(1:num_indirectIrradiance_reg,offset.indirectIrradiance+edge(:,1),weight_indirectIrradiance_reg,num_indirectIrradiance_reg,num_variables)-sparse(1:num_indirectIrradiance_reg,offset.indirectIrradiance+edge(:,2),weight_indirectIrradiance_reg,num_indirectIrradiance_reg,num_variables);
	d4=zeros(num_indirectIrradiance_reg,1);%||C4*x-d4||^2
	
	%indirectIrradiance map should be cloffsete to 0 in log domain
	C5=sparse(1:n,offset.indirectIrradiance+(1:n),ones(1,n),n,num_variables);
	d5=zeros(n,1);%||C5*x-d5||
	
	%illuminationColor regularization
	num_nn_illuminationColor=10;
	ind=randi(n,num_nn_illuminationColor,n);
	edge=[reshape(repmat(1:n,[num_nn_illuminationColor 1]),[],1) reshape(ind,[],1)];%a list of edges N_C
	num_illuminationColor_reg=size(edge,1);
	points_vector=reshape(points,[],3);
	diff=sum(abs(points_vector(edge(:,1),:)-points_vector(edge(:,2),:)),2);
	weight_illuminationColor_reg=(1-diff/max(diff));
	C6=sparse(1:num_illuminationColor_reg*3,offset.illuminationColor+[edge(:,1);edge(:,1)+n;edge(:,1)+n*2],[weight_illuminationColor_reg;weight_illuminationColor_reg;weight_illuminationColor_reg],num_illuminationColor_reg*3,num_variables)-sparse(1:num_illuminationColor_reg*3,offset.illuminationColor+[edge(:,2);edge(:,2)+n;edge(:,2)+n*2],[weight_illuminationColor_reg;weight_illuminationColor_reg;weight_illuminationColor_reg],num_illuminationColor_reg*3,num_variables);
	d6=zeros(num_illuminationColor_reg*3,1);%||C6*x-d6||^2

	%weights on different regularizers w=[data term;albedo;direct irradiance;indirect irradiance;indirect irradiance(simple regularization); illumination color];
	w=[1;0.1;1;1;0.1;1];
	C=[w(1)*C1;w(2)*C2;w(3)*C3;w(4)*C4;w(5)*C5;w(6)*C6];%concatenate the data term and all the regularizers into ||Cx-d||^2
	d=[w(1)*d1;w(2)*d2;w(3)*d3;w(4)*d4;w(5)*d5;w(6)*d6];
	
	%solve a constrainted linear least squared problem
	upper_bound=ones(num_variables,1)*10;
	lower_bound=-upper_bound;
	upper_bound(offset.albedo+(1:n*3))=0;
	upper_bound(offset.illuminationColor+(1:n*3))=0;
	solution=lsqlin(C,d,[],[],[],[],lower_bound,upper_bound);
	
	%extract albedo, direct irradiance, indirect irradiance and illumination color from solution
	albedo=exp(reshape(solution(offset.albedo+(1:3*n)),size(image)));
	directIrradiance=repmat(exp(reshape(solution(offset.directIrradiance+(1:n)),[size(image,1) size(image,2)])),[1 1 3]);
	indirectIrradiance=repmat(exp(reshape(solution(offset.indirectIrradiance+(1:n)),[size(image,1) size(image,2)])),[1 1 3]);
	illuminationColor=exp(reshape(solution(offset.illuminationColor+(1:3*n)),size(image)));
	
	%balance the weight between the albedo and shading images
	shading=directIrradiance.*indirectIrradiance.*illuminationColor;
	[albedo shading]=adjust(albedo,shading);
	directIrradiance=shading./(illuminationColor.*indirectIrradiance);
	
	%print the output image
	imwrite(albedo,[outputDir sprintf('albedo%04d.png',id)]);
	imwrite(shading,[outputDir sprintf('shading%04d.png',id)]);	
	imwrite(directIrradiance,[outputDir sprintf('directIrradiance%04d.png',id)]);	
	imwrite(indirectIrradiance,[outputDir sprintf('indirectIrradiance%04d.png',id)]);	
	imwrite(illuminationColor,[outputDir sprintf('illuminationColor%04d.png',id)]);		
end
